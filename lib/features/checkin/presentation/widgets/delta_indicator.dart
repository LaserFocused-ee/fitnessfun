import 'package:flutter/material.dart';

import '../../domain/utils/checkin_comparison.dart';

/// Shows an up/down arrow with delta value.
///
/// Renders:
/// - Green up arrow with text for positive changes (e.g., "↑ +1.2")
/// - Red down arrow with text for negative changes (e.g., "↓ -2")
/// - Gray arrow for context-dependent changes (e.g., weight)
/// - Nothing if delta is neutral or below threshold
class DeltaIndicator extends StatelessWidget {
  const DeltaIndicator({
    super.key,
    required this.delta,
    this.showArrow = true,
    this.compact = false,
  });

  final MetricDelta delta;

  /// Whether to show the arrow icon.
  final bool showArrow;

  /// Whether to use compact styling (smaller font).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!delta.hasValue || delta.direction == DeltaDirection.neutral) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final color = _getColor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showArrow)
          Icon(
            _getArrowIcon(),
            size: compact ? 12 : 14,
            color: color,
          ),
        if (showArrow) const SizedBox(width: 2),
        Text(
          delta.displayText,
          style: (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
              ?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  IconData _getArrowIcon() {
    switch (delta.direction) {
      case DeltaDirection.up:
        return Icons.arrow_upward;
      case DeltaDirection.down:
        return Icons.arrow_downward;
      case DeltaDirection.neutral:
        return Icons.horizontal_rule;
    }
  }

  Color _getColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (delta.isPositive) {
      return Colors.green.shade600;
    } else if (delta.isNegative) {
      return Colors.red.shade600;
    } else {
      // Context-dependent (like weight) - use a neutral gray
      return colorScheme.onSurface.withValues(alpha: 0.5);
    }
  }
}

/// A more detailed delta indicator with label, good for inline display.
class DeltaIndicatorWithLabel extends StatelessWidget {
  const DeltaIndicatorWithLabel({
    super.key,
    required this.delta,
    required this.positiveLabel,
    required this.negativeLabel,
  });

  final MetricDelta delta;

  /// Label to show when delta is positive (e.g., "improved").
  final String positiveLabel;

  /// Label to show when delta is negative (e.g., "worse").
  final String negativeLabel;

  @override
  Widget build(BuildContext context) {
    if (!delta.hasValue || delta.direction == DeltaDirection.neutral) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isPositive = delta.isPositive;
    final color = isPositive ? Colors.green.shade600 : Colors.red.shade600;
    final label = isPositive ? positiveLabel : negativeLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            delta.direction == DeltaDirection.up
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
