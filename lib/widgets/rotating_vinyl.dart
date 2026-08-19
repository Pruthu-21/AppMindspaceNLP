import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class RotatingVinyl extends StatefulWidget {
  final double size;
  const RotatingVinyl({Key? key, this.size = 90}) : super(key: key);

  @override
  State<RotatingVinyl> createState() => _RotatingVinylState();
}

class _RotatingVinylState extends State<RotatingVinyl> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.black87 : Colors.grey.shade900,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: widget.size * 0.33,
            height: widget.size * 0.33,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: widget.size * 0.18,
            ),
          ),
        ),
      ),
    );
  }
}
