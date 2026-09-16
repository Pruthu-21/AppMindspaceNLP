import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'pages/auth/login_page.dart';
import 'pages/navigation_shell.dart';
import 'pages/profile_page.dart';
import 'services/auth_manager.dart';
import 'services/language_notifier.dart';
import 'services/offline_access_tracker.dart';
import 'services/message_service.dart';

import 'services/notification_service.dart';
import 'pages/splash_page.dart';
import 'services/firebase_stub.dart' if (dart.library.io) 'services/firebase_mobile.dart' as fb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase setup is moved to _checkSession() inside AppStartupHelper

  try {
    await NotificationService().init();
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
  
  runApp(const MindSpaceDriveApp());
}

class MindSpaceDriveApp extends StatelessWidget {
  const MindSpaceDriveApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.themeMode,
      builder: (context, currentThemeMode, child) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageNotifier.language,
          builder: (context, currentLanguage, child) {
            return MaterialApp(
              title: LanguageNotifier.translate('title'),
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentThemeMode,
              home: const SplashPage(),
            );
          },
        );
      },
    );
  }
}

class AppStartupHelper extends StatefulWidget {
  const AppStartupHelper({Key? key}) : super(key: key);

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
