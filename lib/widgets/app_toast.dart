import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppToast {
  static OverlayEntry? _currentEntry;

  static void showSuccess(BuildContext context, String message) {
    _showOverlay(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.success,
      borderColor: AppColors.success.withValues(alpha: 0.3),
    );
  }

  static void showError(BuildContext context, String message) {
    _showOverlay(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.error,
      borderColor: AppColors.error.withValues(alpha: 0.3),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showOverlay(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.primary,
      borderColor: AppColors.primary.withValues(alpha: 0.3),
    );
  }

  static void _showOverlay(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
  }) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return _ToastWidget(
          message: message,
          icon: icon,
          iconColor: iconColor,
          borderColor: borderColor,
          isDark: isDark,
          onDismiss: () {
            try {
              entry.remove();
            } catch (_) {}
            if (_currentEntry == entry) {
              _currentEntry = null;
            }
          },
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final bool isDark;
  final VoidCallback onDismiss;

  const _ToastWidget({
    Key? key,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.isDark,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                _controller.reverse().then((_) {
                  widget.onDismiss();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: widget.iconColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
