import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final Widget? trailing;

  const SectionHeader({
    Key? key,
    required this.title,
    this.actionText,
    this.onActionPressed,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          if (trailing != null)
            trailing!
          else if (actionText != null && onActionPressed != null)
            TextButton(
              onPressed: onActionPressed,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Row(
                children: [
                  Text(
                    actionText!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
