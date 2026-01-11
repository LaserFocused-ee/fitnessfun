import 'package:flutter/material.dart';

/// App color constants.
///
/// Primary colors are used for branding.
/// These are used with ColorScheme.fromSeed for Material 3 theming.
abstract final class AppColors {
  /// Primary brand color - fitness/health green
  static const Color primary = Color(0xFF2E7D32);

  /// Secondary accent color
  static const Color secondary = Color(0xFF558B2F);

  /// Error color
  static const Color error = Color(0xFFB00020);

  /// Success color (for completed workouts, etc.)
  static const Color success = Color(0xFF4CAF50);

  /// Warning color
  static const Color warning = Color(0xFFFF9800);

  /// Rating scale colors (1-7)
  static const List<Color> ratingColors = [
    Color(0xFFD32F2F), // 1 - Very bad (red)
    Color(0xFFF57C00), // 2 - Bad (orange)
    Color(0xFFFFA000), // 3 - Below average (amber)
    Color(0xFFFFEB3B), // 4 - Average (yellow)
    Color(0xFF8BC34A), // 5 - Above average (light green)
    Color(0xFF4CAF50), // 6 - Good (green)
    Color(0xFF2E7D32), // 7 - Excellent (dark green)
  ];

  /// Get color for a rating value (1-7).
  static Color getRatingColor(int rating) {
    final index = (rating - 1).clamp(0, 6);
    return ratingColors[index];
  }
}
