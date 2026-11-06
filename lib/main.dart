import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/reminder_model.dart';
import 'services/reminder_repository.dart';

import 'dart:convert';
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
import 'services/firebase_stub.dart'
    if (dart.library.io) 'services/firebase_mobile.dart'
    as fb;
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/messages_page.dart';

import 'pages/alarm_screen.dart';
import 'pages/splash_page.dart';

Map<String, dynamic>? pendingNotificationTarget;

Future<void> openUrlOrFallback(String link) async {
  final uri = Uri.tryParse(link);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    bool nativeSuccess = false;
    const platform = MethodChannel('mindspace/app');
    try {
      nativeSuccess =
          await platform.invokeMethod('openUrl', {'url': link}) ?? false;
      debugPrint('MSNLP_NOTIF: openUrl result: $nativeSuccess for $link');
      if (nativeSuccess) {
        await Future.delayed(const Duration(milliseconds: 400));
        await platform.invokeMethod('moveTaskToBack');
      }
    } catch (e) {
      debugPrint('Error invoking native openUrl: $e');
    }

    if (!nativeSuccess) {
      debugPrint(
        'MSNLP_NOTIF: native openUrl failed, falling back to launchUrl for $link',
      );
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
  debugPrint(
    'MSNLP_NOTIF: openMessagesFromNotification called with data: $data, navigatorKey.currentState is ${navigatorKey.currentState}',
  );
  final link = data['link'];
  final actionId = data['actionId'];

  if (actionId == 'open_link' &&
      link != null &&
      link is String &&
      link.isNotEmpty) {
    debugPrint('MSNLP_NOTIF: actionId is open_link, parsing link: $link');
    openUrlOrFallback(link);
    return; // Do NOT navigate to MessagesPage
  }

  final nav = navigatorKey.currentState;
  final token = AuthManager.token;

  // If navigator is not ready, or token is null (not logged in yet)
  if (nav == null || token == null) {
    debugPrint(
      'MSNLP_NOTIF: nav or token is null, storing pendingNotificationTarget',
    );
    pendingNotificationTarget = data;
    return;
  }

  MessageService().checkUnreadMessages(token);

  final type = data['type'];
  if (type == 'reminder' || actionId == 'stop_id') {
    final reminderId = data['id'] as int? ?? 0;
    final title = data['title'] as String? ?? 'Mindspace Reminder';

    debugPrint('MSNLP_NOTIF: Pushing AlarmScreen for id $reminderId');
    nav.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/alarm'),
        builder: (_) => AlarmScreen(reminderId: reminderId, title: title),
      ),
    );
    return;
  }

  bool isMessagesTop = false;
  nav.popUntil((route) {
    if (route.settings.name == '/messages') {
      isMessagesTop = true;
    }
    return true; // We don't actually pop anything, just checking if it's on top.
  });

  if (!isMessagesTop) {
    debugPrint('MSNLP_NOTIF: Pushing MessagesPage');
    nav.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/messages'),
        builder: (_) => MessagesPage(userToken: token),
      ),
    );
  } else {
    debugPrint('MSNLP_NOTIF: MessagesPage is already top');
  }
}

// Removed globalGifCodecFuture
late Future<bool> globalSessionCheckFuture;

Future<void> main() async {
  final stopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Pre-load theme so the Flutter splash screen immediately knows the correct theme
  await ThemeNotifier.loadTheme();

  globalSessionCheckFuture = () async {
    // Load preferences and init Firebase in parallel
    try {
      await Future.wait([
        LanguageNotifier.loadLanguage(),
        fb.initFirebaseOnly(),
      ]);
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }

    try {
      final initialData = await fb.getInitialMessageData();
      if (initialData != null) {
        if (initialData['actionId'] == 'open_link') {
          final link = initialData['link'];
          if (link != null && link is String && link.isNotEmpty) {
            openUrlOrFallback(link);
          }
        } else {
          pendingNotificationTarget = initialData;
        }
      } else {
        final plugin = NotificationService().flutterLocalNotificationsPlugin;
        final launchDetails = await plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp ?? false) {
          final response = launchDetails!.notificationResponse;
          if (response?.payload != null) {
            final data = json.decode(response!.payload!);
            final actionId = response.actionId ?? data['actionId'];
            if (actionId == 'open_link') {
              final link = data['link'];
              if (link != null && link is String && link.isNotEmpty) {
                openUrlOrFallback(link);
              }
            } else {
              pendingNotificationTarget = data;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking early launch details: $e');
    }

    return await AuthManager.tryAutoLogin().timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
  }();

  // Defer notification init and rescheduling to post-frame
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationService().init();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('reminders_migrated_v1') != true) {
        await NotificationService().flutterLocalNotificationsPlugin.cancelAll();
        final reminderString = prefs.getString('user_reminder');
        if (reminderString != null) {
          final savedTime = DateTime.tryParse(reminderString);
          if (savedTime != null) {
            final repo = ReminderRepository();
            final r = Reminder(
              id: DateTime.now().millisecondsSinceEpoch % 100000,
              title: 'Mindspace Reminder',
              hour: savedTime.hour,
              minute: savedTime.minute,
              repeat: RepeatType.daily,
              weekdays: [],
              enabled: true,
              createdAt: DateTime.now(),
            );
            await repo.addReminder(r);
          }
        }
        await prefs.setBool('reminders_migrated_v1', true);
      }
      await NotificationService().rescheduleAll();
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  });

  debugPrint(
    'MSNLP_SPLASH: Time before runApp: ${stopwatch.elapsedMilliseconds}ms',
  );
  runApp(MindSpaceDriveApp(skipSplash: false, stopwatch: stopwatch));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MindSpaceDriveApp extends StatelessWidget {
  final bool skipSplash;
  final Stopwatch stopwatch;
  const MindSpaceDriveApp({
    super.key,
    this.skipSplash = false,
    required this.stopwatch,
  });

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
              home: skipSplash
                  ? AppStartupHelper(stopwatch: stopwatch)
                  : SplashPage(stopwatch: stopwatch),
            );
          },
        );
      },
    );
  }
}

class AppStartupHelper extends StatefulWidget {
  final Stopwatch? stopwatch;
  const AppStartupHelper({super.key, this.stopwatch});

  @override
  State<AppStartupHelper> createState() => _AppStartupHelperState();
}

class _AppStartupHelperState extends State<AppStartupHelper>
    with WidgetsBindingObserver {
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
    if (!_isLoggedIn) return;
    final token = AuthManager.token;
    if (token == null) return;

    if (state == AppLifecycleState.resumed) {
      _messageService.updateOnlineStatus(token, true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _messageService.updateOnlineStatus(token, false);
    }
  }

  Future<void> _checkSession() async {
    final loggedIn = await globalSessionCheckFuture;

    OfflineAccessTracker.syncPendingLogs();

    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _isLoading = false;
      });
      if (widget.stopwatch != null) {
        debugPrint(
          'MSNLP_SPLASH: First usable screen visible at ${widget.stopwatch!.elapsedMilliseconds}ms',
        );
      }
    }

    if (loggedIn) {
      final token = AuthManager.token;
      if (token != null) {
        _messageService.updateOnlineStatus(token, true);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await fb.setupFirebase(_messageService, token);
        });

        if (pendingNotificationTarget != null) {
          final target = pendingNotificationTarget!;
          pendingNotificationTarget = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            openMessagesFromNotification(target);
          });
        }
      }
    } else {
      // Not logged in, pending notification should be cleared so they don't fire post-login randomly.
      pendingNotificationTarget = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isLoggedIn ? const NavigationShell() : const LoginPage();
  }
}
