import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/mock_data.dart';
import '../services/role_manager.dart';
import '../services/auth_manager.dart';
import '../services/language_notifier.dart';
import '../services/app_storage.dart';
import '../widgets/profile_tile.dart';
import 'auth/login_page.dart';
import 'reviews_page.dart';
import 'privacy_permissions_page.dart';
import 'help_faq_page.dart';

// A dynamic theme state notifier to allow theme toggling in the UI
class ThemeNotifier {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  
  static Future<void> loadTheme() async {
    try {
      final themeStr = await AppStorage.read('app_theme');
      if (themeStr == 'dark') {
        themeMode.value = ThemeMode.dark;
      } else {
        themeMode.value = ThemeMode.light;
      }
    } catch (_) {
      themeMode.value = ThemeMode.light;
    }
  }

  static Future<void> toggleTheme(bool isDark) async {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final themeStr = isDark ? 'dark' : 'light';
    try {
      await AppStorage.write('app_theme', themeStr);
    } catch (_) {}
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isDarkMode = false;
  String _activeLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeNotifier.themeMode.value == ThemeMode.dark;
    _updateActiveLanguage();
    LanguageNotifier.language.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageNotifier.language.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        _updateActiveLanguage();
      });
    }
  }

  void _updateActiveLanguage() {
    final code = LanguageNotifier.language.value;
    if (code == 'hi') {
      _activeLanguage = 'हिंदी (Hindi)';
    } else if (code == 'gu') {
      _activeLanguage = 'ગુજરાતી (Gujarati)';
    } else {
      _activeLanguage = 'English';
    }
  }

  void _handleLogout() {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            LanguageNotifier.translate('logout'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(LanguageNotifier.translate('confirm_logout')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                LanguageNotifier.translate('cancel'),
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await AuthManager.logout();
                
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              child: Text(
                LanguageNotifier.translate('logout'),
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageSelector() {
    final languages = [
      {'name': 'English', 'code': 'en'},
      {'name': 'हिंदी (Hindi)', 'code': 'hi'},
      {'name': 'ગુજરાતી (Gujarati)', 'code': 'gu'},
    ];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                LanguageNotifier.translate('language'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...languages.map((lang) {
                final isSelected = LanguageNotifier.language.value == lang['code'];
                return ListTile(
                  title: Text(
                    lang['name']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
                  onTap: () async {
                    await LanguageNotifier.setLanguage(lang['code']!);
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAdmin = RoleManager.isAdmin;

    const used = MockData.usedStorageGB;
    const total = MockData.totalStorageGB;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LanguageNotifier.translate('profile'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Avatar & Name Card
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          AuthManager.currentUser?.initials ?? 'MS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AuthManager.currentUser?.name ?? 'Mannu Sharma',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AuthManager.currentUser?.email ?? 'mannu.sharma@mindspacenlp.com',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    if (AuthManager.currentUser != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${LanguageNotifier.translate('user_id')}: #${AuthManager.currentUser!.id}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 32),
                // Subscription Upgrade Plan Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'FREE PLAN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Need More Storage?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upgrade to Pro for 1 TB files, advanced security and priority sync.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Plan upgrade sheet (UI only)')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Storage Progress Indicator Card (Only visible to Admin)
              if (isAdmin) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    border: Border.all(
                      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Storage Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${used.toStringAsFixed(1)} GB of $total GB',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: used / total,
                          color: theme.colorScheme.primary,
                          backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Settings Header
              Text(
                'Settings & Preferences',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              // Settings Tiles
              ProfileTile(
                icon: Icons.dark_mode_rounded,
                title: LanguageNotifier.translate('theme'),
                subtitle: 'Toggle dark interface preference',
                trailing: Switch(
                  value: _isDarkMode,
                  onChanged: (val) {
                    setState(() {
                      _isDarkMode = val;
                      ThemeNotifier.toggleTheme(_isDarkMode);
                    });
                  },
                  activeColor: theme.colorScheme.primary,
                ),
                onTap: () {},
              ),
              ProfileTile(
                icon: Icons.language_rounded,
                title: LanguageNotifier.translate('language'),
                subtitle: 'Change app localization',
                trailing: Row(
                  children: [
                    Text(
                      _activeLanguage,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
                onTap: _showLanguageSelector,
              ),
              ProfileTile(
                icon: Icons.star_rate_rounded,
                title: 'App Reviews',
                subtitle: 'Browse average scores & write reviews',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReviewsPage()),
                  );
                },
              ),
              ProfileTile(
                icon: Icons.shield_rounded,
                title: 'Privacy & Permissions',
                subtitle: 'Control authentication rules',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PrivacyPermissionsPage()),
                  );
                },
              ),
              ProfileTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & FAQ Center',
                subtitle: 'User manuals and support paths',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpFaqPage()),
                  );
                },
              ),
              if (AuthManager.currentUser?.role == AppRole.admin) ...[
                ProfileTile(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Admin Console Mode',
                  subtitle: 'Toggle between Admin and User interfaces',
                  trailing: Switch(
                    value: isAdmin,
                    onChanged: (val) {
                      setState(() {
                        RoleManager.switchRole(val ? AppRole.admin : AppRole.user);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Switched to ${val ? "Admin" : "User"} Mode'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                  onTap: () {},
                ),
              ],
              const Divider(height: 24),
              ProfileTile(
                icon: Icons.logout_rounded,
                title: LanguageNotifier.translate('logout'),
                isDestructive: true,
                onTap: _handleLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
