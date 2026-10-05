import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static bool _hasRequestedThisSession = false;

  static Future<void> checkAndRequestPermissions(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    
    final lastCheckedVersion = prefs.getString('permission_checked_version');
    final isNewVersion = lastCheckedVersion != packageInfo.version;

    // Run the check after splash once the user is logged in, and again after an app update
    if (_hasRequestedThisSession && !isNewVersion) return;
    
    // Do not run if app is in background
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
        WidgetsBinding.instance.lifecycleState != null) {
      return;
    }

    _hasRequestedThisSession = true;
    prefs.setString('permission_checked_version', packageInfo.version);

    if (!Platform.isAndroid) return;

    // Notifications
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      if (!context.mounted) return;
      bool shouldRequest = await _showExplanationDialog(
        context,
        'Notifications',
        'We need notification permission to send you reminders and messages.',
      );
      if (shouldRequest) {
        final res = await Permission.notification.request();
        if (res.isPermanentlyDenied) {
          if (!context.mounted) return;
          await _showSettingsDialog(context, 'Notifications');
        }
      }
    }

    // Exact Alarms
    final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    if (exactAlarmStatus.isDenied) {
      if (!context.mounted) return;
      bool shouldRequest = await _showExplanationDialog(
        context,
        'Exact Alarms',
        'We need exact alarm permission to make sure your reminders trigger exactly on time.',
      );
      if (shouldRequest) {
        final res = await Permission.scheduleExactAlarm.request();
        if (res.isPermanentlyDenied || res.isDenied) {
          // If denied, Android 12+ requires opening settings
          if (!context.mounted) return;
          await _showSettingsDialog(context, 'Exact Alarms');
        }
      }
    }

    // Battery Optimization
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (batteryStatus.isDenied) {
      if (!context.mounted) return;
      bool shouldRequest = await _showExplanationDialog(
        context,
        'Battery Optimization',
        'To ensure reminders work in the background, please exempt the app from battery optimizations.',
      );
      if (shouldRequest) {
        final res = await Permission.ignoreBatteryOptimizations.request();
        if (res.isPermanentlyDenied) {
          if (!context.mounted) return;
          await _showSettingsDialog(context, 'Battery Optimization');
        }
      }
    }

    // Full-Screen Intent (Android 14+)
    // flutter_local_notifications plugin can request it
    final flnPlugin = FlutterLocalNotificationsPlugin();
    final androidPlugin = flnPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // There's no direct way to check if full screen intent is granted via permission_handler,
      // but we can request it. We will just try to request it.
      // Wait, we can't check status easily. Let's just ask if we know we need it?
      // Actually Android 14+ requires it. We'll just call it if SDK >= 34.
      // Unfortunately we don't have device_info_plus, but we can just call requestFullScreenIntentPermission.
      if (!context.mounted) return;
      bool shouldRequest = await _showExplanationDialog(
        context,
        'Full-Screen Intent',
        'We need full-screen intent permission to show reminders over other apps.',
      );
      if (shouldRequest) {
        await androidPlugin.requestFullScreenIntentPermission();
      }
    }
  }

  static Future<bool> _showExplanationDialog(
      BuildContext context, String title, String content) async {
    if (!context.mounted) return false;
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> _showSettingsDialog(BuildContext context, String permissionName) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Denied'),
        content: Text('Please enable $permissionName in the app settings to use this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
