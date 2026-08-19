import 'package:flutter/material.dart';

enum AppRole { user, admin }

class RoleManager {
  static final ValueNotifier<AppRole> roleNotifier = ValueNotifier<AppRole>(AppRole.user);

  static bool get isAdmin => roleNotifier.value == AppRole.admin;
  static bool get isUser => roleNotifier.value == AppRole.user;

  static void switchRole(AppRole role) {
    roleNotifier.value = role;
  }
}
