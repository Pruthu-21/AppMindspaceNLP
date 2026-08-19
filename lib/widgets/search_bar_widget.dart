import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SearchBarWidget extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterPressed;

  const SearchBarWidget({
    Key? key,
    required this.hintText,
    this.onChanged,
    this.onFilterPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            size: 20,
          ),
          suffixIcon: onFilterPressed != null
              ? IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  onPressed: onFilterPressed,
                )
              : null,
          fillColor: Colors.transparent,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
        ),
      ),
    );
  }
}
