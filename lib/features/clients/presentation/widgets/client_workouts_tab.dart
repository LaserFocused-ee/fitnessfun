import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../workout/domain/entities/workout_session.dart';
import '../providers/client_detail_provider.dart';

/// Tab displaying a client's workout session history for trainers.
class ClientWorkoutsTab extends ConsumerWidget {
  const ClientWorkoutsTab({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(clientWorkoutSessionsProvider(clientId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return sessionsAsync.when(
      data: (sessions) {
        // Filter only completed sessions
        final completedSessions =
            sessions.where((s) => s.completedAt != null).toList();

        if (completedSessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fitness_center_outlined,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No workouts yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Client has not completed any workouts',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedSessions.length,
          itemBuilder: (context, index) {
            final session = completedSessions[index];
            return _WorkoutSessionCard(session: session);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(clientWorkoutSessionsProvider(clientId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutSessionCard extends StatefulWidget {
  const _WorkoutSessionCard({required this.session});

  final WorkoutSession session;

  @override
  State<_WorkoutSessionCard> createState() => _WorkoutSessionCardState();
}

class _WorkoutSessionCardState extends State<_WorkoutSessionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = widget.session;
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

    // Calculate duration
    var durationText = '-';
    if (session.startedAt != null && session.completedAt != null) {
      final duration = session.completedAt!.difference(session.startedAt!);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (hours > 0) {
        durationText = '${hours}h ${minutes}m';
      } else {
        durationText = '$minutes min';
      }
    }

    // Count completed exercises
    final completedExercises =
        session.exerciseLogs.where((log) => log.completed).length;
    final totalExercises = session.exerciseLogs.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.planName ?? 'Workout',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Date and time
              if (session.completedAt != null)
                Text(
                  dateFormat.format(session.completedAt!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),

              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _StatChip(
                    icon: Icons.timer_outlined,
                    label: durationText,
                  ),
                  const SizedBox(width: 16),
                  _StatChip(
                    icon: Icons.check_circle_outline,
                    label: '$completedExercises/$totalExercises exercises',
                  ),
                ],
              ),

              // Expanded details
              if (_isExpanded && session.exerciseLogs.isNotEmpty) ...[
                const Divider(height: 24),
                _buildExerciseDetails(context, session),
              ],

              // Notes
              if (session.notes != null && session.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notes,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.notes!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseDetails(BuildContext context, WorkoutSession session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercises',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...session.exerciseLogs.map((log) => _ExerciseLogItem(log: log)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ExerciseLogItem extends StatelessWidget {
  const _ExerciseLogItem({required this.log});

  final ExerciseLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Count completed sets
    final completedSets = log.setData.where((s) => s.completed).length;
    final totalSets = log.setData.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            log.completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color:
                log.completed ? Colors.green : colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.exerciseName ?? 'Exercise',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: log.completed ? FontWeight.w500 : FontWeight.normal,
                color: log.completed
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            '$completedSets/$totalSets sets',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
