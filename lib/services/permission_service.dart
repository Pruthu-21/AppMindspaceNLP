import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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

const kAskFullScreenIntent = true;

    // Full-Screen Intent (Android 14+)
    if (kAskFullScreenIntent) {
      final methodChannel = const MethodChannel('mindspace/permissions');
      final canUse = await methodChannel.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
      
      if (!canUse) {
        final lastFsiVersion = prefs.getString('fsi_asked_version');
        if (lastFsiVersion != packageInfo.version) {
          prefs.setString('fsi_asked_version', packageInfo.version);
          if (!context.mounted) return;
          
          bool? result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Full-Screen Intent'),
              content: const Text('Allow full-screen alarms so a reminder can wake your screen when the phone is locked.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Not now'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open settings'),
                ),
              ],
            ),
          );
          
          if (result == true) {
            await methodChannel.invokeMethod('openFullScreenIntentSettings');
            
            // Wait for app to resume to re-check
            final observer = _LifecycleEventHandler(
              resumeCallBack: () async {
                final granted = await methodChannel.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
                if (granted) {
                  debugPrint('FSI granted on resume');
                }
              }
            );
            WidgetsBinding.instance.addObserver(observer);
          }
        }
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

class _LifecycleEventHandler extends WidgetsBindingObserver {
  final Future<void> Function() resumeCallBack;

  _LifecycleEventHandler({required this.resumeCallBack});

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await resumeCallBack();
      WidgetsBinding.instance.removeObserver(this);
    }
  }
}
