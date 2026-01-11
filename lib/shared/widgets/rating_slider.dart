import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A slider widget for rating on a 1-7 scale.
class RatingSlider extends StatelessWidget {
  const RatingSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.lowLabel = 'Low',
    this.highLabel = 'High',
    this.invertColors = false,
  });

  final String label;
  final int? value;
  final void Function(int?) onChanged;
  final String lowLabel;
  final String highLabel;

  /// If true, low values show green and high values show red.
  final bool invertColors;

  @override
  Widget build(BuildContext context) {
    final currentValue = value ?? 4;
    final color = invertColors
        ? AppColors.ratingColors[6 - (currentValue - 1).clamp(0, 6)]
        : AppColors.getRatingColor(currentValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    currentValue.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: currentValue.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                onChanged: (v) => onChanged(v.toInt()),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lowLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                Text(
                  highLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
