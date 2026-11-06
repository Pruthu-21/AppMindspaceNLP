import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class FabMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const FabMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });
}

class ExpandableFabMenu extends StatefulWidget {
  final List<FabMenuItem> items;
  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback onClose;
  final String heroTag;

  const ExpandableFabMenu({
    super.key,
    required this.items,
    required this.isOpen,
    required this.onToggle,
    required this.onClose,
    this.heroTag = 'admin_expandable_fab',
  });

  @override
  State<ExpandableFabMenu> createState() => _ExpandableFabMenuState();
}

class _ExpandableFabMenuState extends State<ExpandableFabMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuad,
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: math.pi / 4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    if (widget.isOpen) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant ExpandableFabMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Drop-up menu items
        IgnorePointer(
          ignoring: !widget.isOpen,
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              final progress = _expandAnimation.value;
              if (progress == 0.0) return const SizedBox.shrink();

              return Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1.0 - progress) * 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = widget.items.length - 1; i >= 0; i--) ...[
                        _buildMenuItem(
                          context,
                          widget.items[i],
                          i,
                          isDark,
                          theme,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Main Plus / Close FAB
        FloatingActionButton(
          heroTag: widget.heroTag,
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onToggle();
          },
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tooltip: widget.isOpen ? 'Close menu' : 'Actions',
          child: AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value,
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    FabMenuItem item,
    int index,
    bool isDark,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        item.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Item Label Card
          Material(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight,
                ),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Item Icon Button
          Material(
            color: item.backgroundColor ?? theme.colorScheme.primary,
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  item.icon,
                  color: item.iconColor ?? Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
