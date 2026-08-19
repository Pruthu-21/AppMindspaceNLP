import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'pages/auth/login_page.dart';
import 'pages/navigation_shell.dart';
import 'pages/profile_page.dart';
import 'services/auth_manager.dart';
import 'services/language_notifier.dart';
import 'services/offline_access_tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  
  // Load saved theme and language asynchronously on app startup
  await ThemeNotifier.loadTheme();
  await LanguageNotifier.loadLanguage();
  
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
              home: const AppStartupHelper(),
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

class _AppStartupHelperState extends State<AppStartupHelper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
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
