import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/role_manager.dart';
import '../services/auth_manager.dart';
import '../services/language_notifier.dart';
import 'auth/login_page.dart';
import 'home_page.dart';
import 'recent_page.dart';
import 'downloads_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'admin/admin_panel_page.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({Key? key}) : super(key: key);

  static final ValueNotifier<int> navigationNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> hideBottomNavNotifier = ValueNotifier<bool>(false);

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    NavigationShell.navigationNotifier.addListener(_onNavigationChanged);
    _currentIndex = NavigationShell.navigationNotifier.value;

    if (AuthManager.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      });
    }
  }

  @override
  void dispose() {
    NavigationShell.navigationNotifier.removeListener(_onNavigationChanged);
    super.dispose();
  }

  void _onNavigationChanged() {
    if (mounted) {
      setState(() {
        _currentIndex = NavigationShell.navigationNotifier.value;
      });
    }
  }

  // Build the list of pages dynamically based on the current role
  List<Widget> _getPages(AppRole role) {
    if (role == AppRole.admin) {
      return [
        const HomePage(),
        const RecentPage(),
        const AdminPanelPage(),
        const DownloadsPage(),
        const ProfilePage(),
      ];
    } else {
      return [
        const HomePage(),
        const RecentPage(),
        const DownloadsPage(),
        const NotificationsPage(),
        const ProfilePage(),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<AppRole>(
      valueListenable: RoleManager.roleNotifier,
      builder: (context, currentRole, child) {
        final pages = _getPages(currentRole);
        
        // Safety check to prevent index out of bounds if page count changes
        if (_currentIndex >= pages.length) {
          _currentIndex = 0;
        }

        return Scaffold(
          body: Stack(
            children: [
              // Screen contents
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('page-${currentRole.name}-$_currentIndex'),
                  child: pages[_currentIndex],
                ),
              ),
              
              // Floating Premium Bottom Navigation
              ValueListenableBuilder<bool>(
                valueListenable: NavigationShell.hideBottomNavNotifier,
                builder: (context, isHidden, child) {
                  if (isHidden) return const SizedBox.shrink();
                  final bottomInset = MediaQuery.of(context).padding.bottom;
                  return Positioned(
                    bottom: 16 + (bottomInset > 0 ? bottomInset : 8),
                    left: 16,
                    right: 16,
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark.withOpacity(0.95) : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _buildNavItems(currentRole),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildNavItems(AppRole role) {
    if (role == AppRole.admin) {
      return [
        _buildNavItem(0, Icons.home_rounded, LanguageNotifier.translate('home')),
        _buildNavItem(1, Icons.schedule_rounded, LanguageNotifier.translate('recent')),
        _buildNavItem(2, Icons.analytics_rounded, LanguageNotifier.translate('admin_panel')),
        _buildNavItem(3, Icons.download_done_rounded, LanguageNotifier.translate('downloads')),
        _buildNavItem(4, Icons.person_rounded, LanguageNotifier.translate('profile')),
      ];
    } else {
      return [
        _buildNavItem(0, Icons.home_rounded, LanguageNotifier.translate('home')),
        _buildNavItem(1, Icons.schedule_rounded, LanguageNotifier.translate('recent')),
        _buildNavItem(2, Icons.download_done_rounded, LanguageNotifier.translate('downloads')),
        _buildNavItem(3, Icons.notifications_rounded, LanguageNotifier.translate('notifications')),
        _buildNavItem(4, Icons.person_rounded, LanguageNotifier.translate('profile')),
      ];
    }
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final theme = Theme.of(context);
    final isSelected = _currentIndex == index;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        NavigationShell.navigationNotifier.value = index;
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
