import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/mock_data.dart';

class StorageCard extends StatelessWidget {
  final VoidCallback? onUpgradePressed;

  const StorageCard({
    Key? key,
    this.onUpgradePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const used = MockData.usedStorageGB;
    const total = MockData.totalStorageGB;
    const percentage = used / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.surfaceDark,
                  AppColors.surfaceDark.withOpacity(0.8),
                ]
              : [
                  Colors.white,
                  Colors.white.withOpacity(0.9),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Storage',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${used.toStringAsFixed(1)} GB of ${total.toStringAsFixed(0)} GB used',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Beautiful custom multi-color storage indicator track
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (MockData.documentsGB * 10).toInt(),
                    child: Container(color: AppColors.primary),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: (MockData.mediaGB * 10).toInt(),
                    child: Container(color: AppColors.accent),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: (MockData.backupsGB * 10).toInt(),
                    child: Container(color: AppColors.secondary),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: (MockData.othersGB * 10).toInt(),
                    child: Container(color: AppColors.warning),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: ((total - used) * 10).toInt(),
                    child: Container(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Category Indicators Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCategoryDot(context, 'Documents', AppColors.primary, '${MockData.documentsGB} GB'),
              _buildCategoryDot(context, 'Media', AppColors.accent, '${MockData.mediaGB} GB'),
              _buildCategoryDot(context, 'Backups', AppColors.secondary, '${MockData.backupsGB} GB'),
              _buildCategoryDot(context, 'Others', AppColors.warning, '${MockData.othersGB} GB'),
            ],
          ),
          if (onUpgradePressed != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            InkWell(
              onTap: onUpgradePressed,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_upload_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upgrade to Premium',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Get 1 TB storage & advanced encryption',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryDot(BuildContext context, String title, Color color, String amount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            amount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
