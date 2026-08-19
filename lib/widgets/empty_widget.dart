import 'package:flutter/material.dart';

class EmptyWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const EmptyWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onActionPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Premium Illustration graphic using nested container shapes and micro-gradients
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.06),
                        theme.colorScheme.secondary.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
                Icon(
                  icon,
                  size: 40,
                  color: theme.colorScheme.primary.withOpacity(0.8),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white60 : Colors.black45,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onActionPressed != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: 180,
                child: TextButton(
                  onPressed: onActionPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    actionText!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
