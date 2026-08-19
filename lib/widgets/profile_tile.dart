import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isDestructive;

  const ProfileTile({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.isDestructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final leadingColor = isDestructive
        ? AppColors.error
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.error.withOpacity(0.1)
                    : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppColors.error : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? AppColors.error : leadingColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
          ],
        ),
      ),
    );
  }
}
