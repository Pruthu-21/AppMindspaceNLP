import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/review_model.dart';

class ReviewCard extends StatefulWidget {
  final ReviewModel review;
  final VoidCallback? onLikePressed;

  const ReviewCard({
    Key? key,
    required this.review,
    this.onLikePressed,
  }) : super(key: key);

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  late bool _isLiked;
  late int _likes;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.review.isLiked;
    _likes = widget.review.likes;
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likes++;
      } else {
        _likes--;
      }
      widget.review.isLiked = _isLiked;
      widget.review.likes = _likes;
    });
    if (widget.onLikePressed != null) {
      widget.onLikePressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Create a beautiful avatar color based on the first letter of user name
    final avatarColor = _getAvatarColor(widget.review.userName);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [avatarColor.withOpacity(0.8), avatarColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.review.userInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.review.userName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.review.date,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  final fillValue = widget.review.rating - index;
                  if (fillValue >= 1) {
                    return const Icon(Icons.star_rounded, color: AppColors.warning, size: 16);
                  } else if (fillValue >= 0.5) {
                    return const Icon(Icons.star_half_rounded, color: AppColors.warning, size: 16);
                  } else {
                    return Icon(
                      Icons.star_rounded,
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
                      size: 16,
                    );
                  }
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.review.reviewText,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: _toggleLike,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isLiked
                        ? theme.colorScheme.primary.withOpacity(0.08)
                        : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isLiked
                          ? theme.colorScheme.primary.withOpacity(0.2)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                        size: 14,
                        color: _isLiked ? theme.colorScheme.primary : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_likes',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isLiked ? theme.colorScheme.primary : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.info,
      AppColors.success,
      Colors.deepOrange,
      Colors.pink,
      Colors.purple,
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}
