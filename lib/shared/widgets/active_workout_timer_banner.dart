import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../features/workout/presentation/providers/workout_provider.dart';
import '../../features/workout/presentation/providers/workout_timer_provider.dart';

/// A slim, persistent banner that shows the active workout timer.
/// This should be placed in the app builder to appear on all screens.
class ActiveWorkoutTimerBanner extends ConsumerWidget {
  const ActiveWorkoutTimerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(activeWorkoutNotifierProvider);
    final workout = workoutAsync.valueOrNull;

    // Don't show if no active workout
    if (workout == null) {
      return const SizedBox.shrink();
    }

    final elapsed = ref.watch(workoutTimerProvider);
    final restTimer = ref.watch(globalRestTimerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final completedCount = workout.exerciseLogs.where((l) => l.completed).length;
    final totalCount = workout.exerciseLogs.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    // Determine colors based on rest state
    final isResting = restTimer.state != GlobalRestState.working;
    final (bannerColor, textColor, timerBgColor) = _getColors(colorScheme, restTimer.state);

    return Material(
      elevation: 8,
      color: bannerColor,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () {
            // Use router provider since we're outside GoRouter context
            ref.read(routerProvider).push(
              '/client/plans/${workout.planId}/workout?sessionId=${workout.id}',
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Pulsing indicator (changes color based on rest state)
                _PulsingDot(color: isResting ? _getRestIndicatorColor(restTimer.state) : colorScheme.primary),
                const SizedBox(width: 12),

                // Plan name and progress
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.planName ?? 'Workout',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$completedCount/$totalCount exercises',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textColor.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: textColor.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation(
                                  isResting ? _getRestIndicatorColor(restTimer.state) : colorScheme.primary,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Timer display with rest state
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: timerBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: textColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        // Show rest state label + workout elapsed time
                        '${_getRestLabel(restTimer.state)}${elapsed.toWorkoutDisplay()}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Continue arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, Color) _getColors(ColorScheme colorScheme, GlobalRestState state) {
    switch (state) {
      case GlobalRestState.working:
        return (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
          colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
        );
      case GlobalRestState.resting:
        return (
          Colors.orange.shade100,
          Colors.orange.shade900,
          Colors.orange.withValues(alpha: 0.2),
        );
      case GlobalRestState.ready:
        return (
          Colors.blue.shade100,
          Colors.blue.shade900,
          Colors.blue.withValues(alpha: 0.2),
        );
      case GlobalRestState.go:
        return (
          Colors.green.shade100,
          Colors.green.shade900,
          Colors.green.withValues(alpha: 0.2),
        );
    }
  }

  Color _getRestIndicatorColor(GlobalRestState state) {
    switch (state) {
      case GlobalRestState.working:
        return Colors.green;
      case GlobalRestState.resting:
        return Colors.orange;
      case GlobalRestState.ready:
        return Colors.blue;
      case GlobalRestState.go:
        return Colors.green;
    }
  }

  String _getRestLabel(GlobalRestState state) {
    switch (state) {
      case GlobalRestState.working:
        return '';
      case GlobalRestState.resting:
        return 'REST ';
      case GlobalRestState.ready:
        return 'READY ';
      case GlobalRestState.go:
        return 'GO! ';
    }
  }
}

/// A pulsing dot to indicate active workout
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
