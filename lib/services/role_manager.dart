import 'package:flutter/material.dart';
import 'app_storage.dart';

enum AppRole { user, admin }

class RoleManager {
  static const String _prefKey = 'admin_console_mode_preference';
  static final ValueNotifier<AppRole> roleNotifier = ValueNotifier<AppRole>(
    AppRole.user,
  );

  static bool get isAdmin => roleNotifier.value == AppRole.admin;
  static bool get isUser => roleNotifier.value == AppRole.user;

  /// Switches active role and optionally persists the choice to device storage.
  static Future<void> switchRole(AppRole role, {bool persist = true}) async {
    roleNotifier.value = role;
    if (persist) {
      try {
        await AppStorage.write(_prefKey, role.name);
      } catch (e) {
        debugPrint('Error saving admin mode preference: $e');
      }
    }
  }

  /// Resolves the initial role on app startup.
  /// If the account is an admin, respects any saved toggle preference.
  static Future<AppRole> resolveInitialRole(AppRole baseAccountRole) async {
    if (baseAccountRole != AppRole.admin) {
      roleNotifier.value = AppRole.user;
      return AppRole.user;
    }

    try {
      final savedMode = await AppStorage.read(_prefKey);
      if (savedMode == AppRole.user.name) {
        roleNotifier.value = AppRole.user;
        return AppRole.user;
      } else if (savedMode == AppRole.admin.name) {
        roleNotifier.value = AppRole.admin;
        return AppRole.admin;
      }
    } catch (e) {
      debugPrint('Error reading admin mode preference: $e');
    }

    roleNotifier.value = AppRole.admin;
    return AppRole.admin;
  }
}
