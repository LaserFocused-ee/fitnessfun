import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../domain/entities/workout_session.dart';
import '../providers/workout_provider.dart';

/// Displays the client's workout session history
class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(clientWorkoutHistoryProvider());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.home),
        title: const Text('Workout History'),
      ),
      body: historyAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fitness_center_outlined,
                    size: 64,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No workouts yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a workout from your plans to see it here',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Group sessions by date
          final groupedSessions = _groupByDate(sessions);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedSessions.length,
            itemBuilder: (context, index) {
              final dateGroup = groupedSessions[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 16,
                      bottom: 8,
                    ),
                    child: Text(
                      _formatDateHeader(dateGroup.date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Sessions for this date
                  ...dateGroup.sessions.map(
                    (session) => _SessionCard(session: session),
                  ),
                ],
              );
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
                onPressed: () => ref.invalidate(clientWorkoutHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<WorkoutSession> sessions) {
    final groups = <DateTime, List<WorkoutSession>>{};

    for (final session in sessions) {
      final date = session.completedAt ?? session.startedAt ?? DateTime.now();
      final dateOnly = DateTime(date.year, date.month, date.day);
      groups.putIfAbsent(dateOnly, () => []).add(session);
    }

    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedDates
        .map((date) => _DateGroup(date: date, sessions: groups[date]!))
        .toList();
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (date.isAfter(today.subtract(const Duration(days: 7)))) {
      return DateFormat('EEEE').format(date); // Day name (Monday, Tuesday...)
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }
}

class _DateGroup {
  final DateTime date;
  final List<WorkoutSession> sessions;

  _DateGroup({required this.date, required this.sessions});
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final startTime = session.startedAt;
    final endTime = session.completedAt;
    final duration = startTime != null && endTime != null
        ? endTime.difference(startTime)
        : null;

    final completedCount =
        session.exerciseLogs.where((log) => log.completed).length;
    final totalCount = session.exerciseLogs.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSessionDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.planName ?? 'Workout',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (startTime != null)
                    Text(
                      DateFormat('h:mm a').format(startTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _StatChip(
                    icon: Icons.check_circle_outline,
                    label: '$completedCount/$totalCount exercises',
                    color: completedCount == totalCount
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  if (duration != null)
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: _formatDuration(duration),
                      color: colorScheme.outline,
                    ),
                ],
              ),

              // Notes preview
              if (session.notes != null && session.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  void _showSessionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _SessionDetailSheet(
          session: session,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _SessionDetailSheet extends StatelessWidget {
  const _SessionDetailSheet({
    required this.session,
    required this.scrollController,
  });

  final WorkoutSession session;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final startTime = session.startedAt;
    final endTime = session.completedAt;
    final duration = startTime != null && endTime != null
        ? endTime.difference(startTime)
        : null;

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.planName ?? 'Workout',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (startTime != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM d, yyyy \'at\' h:mm a')
                            .format(startTime),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Duration
        if (duration != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${_formatDuration(duration)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Notes
        if (session.notes != null && session.notes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.notes!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Exercise list header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Exercises',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${session.exerciseLogs.where((l) => l.completed).length}/${session.exerciseLogs.length} completed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Exercise list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: session.exerciseLogs.length,
            itemBuilder: (context, index) {
              final log = session.exerciseLogs[index];
              return _ExerciseDetailCard(log: log, index: index);
            },
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}

/// Expandable card showing exercise details with individual sets
class _ExerciseDetailCard extends StatelessWidget {
  const _ExerciseDetailCard({required this.log, required this.index});

  final ExerciseLog log;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final completedSets = log.setData.where((s) => s.completed).length;
    final totalSets = log.setData.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: log.completed
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          child: log.completed
              ? Icon(
                  Icons.check,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                )
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
        ),
        title: Text(
          log.exerciseName ?? 'Exercise ${index + 1}',
          style: TextStyle(
            decoration: log.completed ? null : TextDecoration.lineThrough,
            color: log.completed
                ? null
                : colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        subtitle: Text(
          '$completedSets/$totalSets sets',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        children: [
          // Exercise notes
          if (log.notes != null && log.notes!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.notes!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          // Individual sets
          ...log.setData.map((set) => _SetRow(set: set, colorScheme: colorScheme, theme: theme)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Row showing individual set data
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.colorScheme,
    required this.theme,
  });

  final SetLog set;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final reps = set.reps ?? set.targetReps;
    final weight = set.weight ?? set.targetWeight;
    final wasModified = (set.reps != null && set.reps != set.targetReps) ||
        (set.weight != null && set.weight != set.targetWeight);
    final hasNotes = set.notes != null && set.notes!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              // Set number with completion indicator
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: set.completed
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: set.completed
                      ? Icon(Icons.check, size: 16, color: colorScheme.onPrimaryContainer)
                      : Text(
                          '${set.setNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Reps
              if (reps != null)
                _SetDataChip(
                  label: '$reps reps',
                  isModified: set.reps != null && set.reps != set.targetReps,
                  colorScheme: colorScheme,
                ),
              if (reps != null && weight != null) const SizedBox(width: 8),

              // Weight
              if (weight != null)
                _SetDataChip(
                  label: '${weight}kg',
                  isModified: set.weight != null && set.weight != set.targetWeight,
                  colorScheme: colorScheme,
                ),

              const Spacer(),

              // Notes indicator
              if (hasNotes)
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 16,
                  color: colorScheme.primary,
                ),
              if (hasNotes) const SizedBox(width: 8),

              // Modified indicator
              if (wasModified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'modified',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Notes row
        if (hasNotes)
          Padding(
            padding: const EdgeInsets.only(left: 56, right: 16, bottom: 4),
            child: Text(
              set.notes!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// Chip showing set data with modification highlight
class _SetDataChip extends StatelessWidget {
  const _SetDataChip({
    required this.label,
    required this.isModified,
    required this.colorScheme,
  });

  final String label;
  final bool isModified;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isModified
            ? colorScheme.tertiaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isModified
              ? colorScheme.onTertiaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
