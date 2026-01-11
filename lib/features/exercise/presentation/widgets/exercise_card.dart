import 'package:flutter/material.dart';
import '../../domain/entities/exercise.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.trailing,
  });

  final Exercise exercise;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon/thumbnail
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: exercise.videoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(color: colorScheme.primaryContainer),
                            Icon(
                              Icons.play_circle_outline,
                              color: colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ],
                        ),
                      )
                    : Icon(
                        Icons.fitness_center,
                        color: colorScheme.onPrimaryContainer,
                        size: 28,
                      ),
              ),

              const SizedBox(width: 16),

              // Exercise info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (exercise.isGlobal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Global',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (exercise.muscleGroup != null)
                      Row(
                        children: [
                          Icon(
                            _getMuscleGroupIcon(exercise.muscleGroup!),
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            exercise.muscleGroup!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    if (exercise.instructions != null &&
                        exercise.instructions!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        exercise.instructions!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing widget or chevron
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMuscleGroupIcon(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return Icons.accessibility_new;
      case 'back':
        return Icons.airline_seat_flat;
      case 'shoulders':
        return Icons.accessibility;
      case 'legs':
      case 'quadriceps':
      case 'hamstrings':
      case 'glutes':
      case 'calves':
        return Icons.directions_run;
      case 'core':
        return Icons.self_improvement;
      case 'cardio':
        return Icons.favorite;
      default:
        return Icons.fitness_center;
    }
  }
}
