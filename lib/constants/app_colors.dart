import 'package:flutter/material.dart';

class AppColors {
  // Light Theme Palette
  static const Color primary = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF6366F1);
  static const Color accent = Color(0xFF22C55E);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color dividerLight = Color(0xFFE2E8F0);

  // Dark Theme Palette
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color dividerDark = Color(0xFF334155);

  // Utility colors
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);

  // Glassmorphic styling utilities
  static Color glassBgLight = Colors.white.withOpacity(0.7);
  static Color glassBgDark = const Color(0xFF1E293B).withOpacity(0.7);
}
