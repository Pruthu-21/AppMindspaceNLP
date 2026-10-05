import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'theme/app_theme.dart';
import 'pages/auth/login_page.dart';
import 'pages/navigation_shell.dart';
import 'pages/profile_page.dart';
import 'services/auth_manager.dart';
import 'services/language_notifier.dart';
import 'services/offline_access_tracker.dart';
import 'services/message_service.dart';

import 'services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/firebase_stub.dart' if (dart.library.io) 'services/firebase_mobile.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/messages_page.dart';
import 'pages/splash_page.dart';

Map<String, dynamic>? pendingNotificationTarget;

Future<void> openUrlOrFallback(String link) async {
  final uri = Uri.tryParse(link);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    bool nativeSuccess = false;
    const platform = MethodChannel('mindspace/app');
    try {
      nativeSuccess = await platform.invokeMethod('openUrl', {'url': link}) ?? false;
      debugPrint('MSNLP_NOTIF: openUrl result: $nativeSuccess for $link');
      if (nativeSuccess) {
        await Future.delayed(const Duration(milliseconds: 400));
        await platform.invokeMethod('moveTaskToBack');
      }
    } catch (e) {
      debugPrint('Error invoking native openUrl: $e');
    }
    
    if (!nativeSuccess) {
      debugPrint('MSNLP_NOTIF: native openUrl failed, falling back to launchUrl for $link');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await Future.delayed(const Duration(milliseconds: 400));
        await platform.invokeMethod('moveTaskToBack');
      } catch (e) {
        debugPrint('Error launching url from notification fallback: $e');
      }
    }
  } else {
    debugPrint('MSNLP_NOTIF: Invalid url or scheme: $link');
  }
}

void openMessagesFromNotification(Map<String, dynamic> data) {
  debugPrint('MSNLP_NOTIF: openMessagesFromNotification called with data: $data, navigatorKey.currentState is ${navigatorKey.currentState}');
  final link = data['link'];
  final actionId = data['actionId'];
  
  if (actionId == 'open_link' && link != null && link is String && link.isNotEmpty) {
    debugPrint('MSNLP_NOTIF: actionId is open_link, parsing link: $link');
    openUrlOrFallback(link);
    return; // Do NOT navigate to MessagesPage
  }

  final nav = navigatorKey.currentState;
  final token = AuthManager.token;
  
  // If navigator is not ready, or token is null (not logged in yet)
  if (nav == null || token == null) {
    debugPrint('MSNLP_NOTIF: nav or token is null, storing pendingNotificationTarget');
    pendingNotificationTarget = data;
    return;
  }
  
  MessageService().checkUnreadMessages(token);

  bool isMessagesTop = false;
  nav.popUntil((route) {
    if (route.settings.name == '/messages') {
      isMessagesTop = true;
    }
    return true; // We don't actually pop anything, just checking if it's on top.
  });

  if (!isMessagesTop) {
    debugPrint('MSNLP_NOTIF: Pushing MessagesPage');
    nav.push(MaterialPageRoute(
      settings: const RouteSettings(name: '/messages'),
      builder: (_) => MessagesPage(userToken: token),
    ));
  } else {
    debugPrint('MSNLP_NOTIF: MessagesPage is already top');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase setup is moved to _checkSession() inside AppStartupHelper

  try {
    await NotificationService().init();
    
    // Migration for old notifications
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('reminders_migrated_v1') != true) {
      await NotificationService().flutterLocalNotificationsPlugin.cancelAll();
      
      final reminderString = prefs.getString('user_reminder');
      if (reminderString != null) {
        final savedTime = DateTime.tryParse(reminderString);
        if (savedTime != null) {
          DateTime nextTime = savedTime;
          final now = DateTime.now();
          while (nextTime.isBefore(now)) {
            nextTime = nextTime.add(const Duration(days: 1));
          }
          await NotificationService().scheduleReminder(
            id: 0,
            title: 'Mindspace Reminder',
            body: 'It is time for your scheduled Mindspace session.',
            scheduledDate: nextTime,
          );
        }
      }
      
      await prefs.setBool('reminders_migrated_v1', true);
    }
  } catch (e) {
    debugPrint('Error initializing NotificationService: $e');
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  
  // Load saved theme and language asynchronously on app startup
  try {
    await ThemeNotifier.loadTheme();
    await LanguageNotifier.loadLanguage();
  } catch (e) {
    debugPrint('Error loading preferences: $e');
  }

  bool skipSplash = false;
  try {
    final launchDetails = await NotificationService().flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails!.notificationResponse;
      if (response?.actionId == 'open_link' && response?.payload != null) {
        final data = json.decode(response!.payload!);
        final link = data['link'];
        if (link != null && link is String && link.isNotEmpty) {
          debugPrint('MSNLP_NOTIF: early check actionId open_link, parsing link: $link');
          await openUrlOrFallback(link);
          skipSplash = true;
        }
      }
    }
  } catch (e) {
    debugPrint('Error checking early launch details: $e');
  }
  
  runApp(MindSpaceDriveApp(skipSplash: skipSplash));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MindSpaceDriveApp extends StatelessWidget {
  final bool skipSplash;
  const MindSpaceDriveApp({super.key, this.skipSplash = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.themeMode,
      builder: (context, currentThemeMode, child) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageNotifier.language,
          builder: (context, currentLanguage, child) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: LanguageNotifier.translate('title'),
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentThemeMode,
              home: skipSplash ? const AppStartupHelper() : const SplashPage(),
            );
          },
        );
      },
    );
  }
}

class AppStartupHelper extends StatefulWidget {
  const AppStartupHelper({super.key});

  @override
  State<AppStartupHelper> createState() => _AppStartupHelperState();
}

class _AppStartupHelperState extends State<AppStartupHelper> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  final MessageService _messageService = MessageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    debugPrint('MSNLP_APPSTATE | LIFECYCLE state=${state.name}');
    if (state == AppLifecycleState.paused) {
      debugPrint('MSNLP_APPSTATE | SCREEN_OFF/BACKGROUND state=${state.name}');
    }
    if (!_isLoggedIn) return;
    
    final token = AuthManager.token;
    if (token == null) return;

    if (state == AppLifecycleState.resumed) {
      // User came back to the app
      _messageService.updateOnlineStatus(token, true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // User minimized or closed the app
      _messageService.updateOnlineStatus(token, false);
    }
  }

  Future<void> _checkSession() async {
    final loggedIn = await AuthManager.tryAutoLogin();
    
    // Once login check is complete (and token is loaded if successful), sync any pending offline logs.
    // If the device is currently offline, this will start a periodic timer to retry.
    OfflineAccessTracker.syncPendingLogs();

    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });

    if (loggedIn) {
      final token = AuthManager.token;
      if (token != null) {
        _messageService.updateOnlineStatus(token, true);
        await fb.setupFirebase(_messageService, token);
        
        try {
          final launchDetails = await NotificationService().flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
          if (launchDetails?.didNotificationLaunchApp ?? false) {
             final payload = launchDetails?.notificationResponse?.payload;
             if (payload != null && payload.isNotEmpty) {
                final data = json.decode(payload);
                if (data['actionId'] == null && launchDetails!.notificationResponse?.actionId != null) {
                   data['actionId'] = launchDetails.notificationResponse!.actionId;
                }
                if (data['actionId'] != 'open_link') {
                   pendingNotificationTarget ??= data;
                }
             }
          }
          
          if (!kIsWeb) {
            final initialData = await fb.getInitialMessageData();
            if (initialData != null && pendingNotificationTarget == null) {
              if (initialData['actionId'] != 'open_link') {
                pendingNotificationTarget = initialData;
              }
            }
          }
        } catch (e) {
          debugPrint('Error getting launch details in _checkSession: $e');
        }

        if (pendingNotificationTarget != null) {
          debugPrint('MSNLP_NOTIF: Consuming pendingNotificationTarget: $pendingNotificationTarget');
          final target = pendingNotificationTarget!;
          pendingNotificationTarget = null;
          // Wait a tick for NavigationShell to build, then open messages
          WidgetsBinding.instance.addPostFrameCallback((_) {
            openMessagesFromNotification(target);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _isLoggedIn ? const NavigationShell() : const LoginPage();
  }
}
