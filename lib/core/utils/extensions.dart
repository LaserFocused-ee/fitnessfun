import 'package:flutter/material.dart';

/// Extension on BuildContext for easier access to theme and media query.
extension BuildContextX on BuildContext {
  /// Access the current theme.
  ThemeData get theme => Theme.of(this);

  /// Access the current color scheme.
  ColorScheme get colorScheme => theme.colorScheme;

  /// Access the current text theme.
  TextTheme get textTheme => theme.textTheme;

  /// Access the media query data.
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Screen width.
  double get screenWidth => mediaQuery.size.width;

  /// Screen height.
  double get screenHeight => mediaQuery.size.height;

  /// Whether we're on a tablet-sized screen.
  bool get isTablet => screenWidth >= 600;

  /// Whether we're on a desktop-sized screen.
  bool get isDesktop => screenWidth >= 1200;
}

/// Extension on DateTime for formatting.
extension DateTimeX on DateTime {
  /// Format as "Jan 1, 2025"
  String get formatted {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[month - 1]} $day, $year';
  }

  /// Format as "Monday, Jan 1"
  String get formattedWithDay {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[weekday - 1]}, ${months[month - 1]} $day';
  }

  /// Check if this date is today.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if this date is yesterday.
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }
}

/// Extension on Duration for formatting.
extension DurationX on Duration {
  /// Format as "Xh Ym" (e.g., "7h 30m" for sleep duration).
  String get formatted {
    final hours = inHours;
    final minutes = inMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }
}
