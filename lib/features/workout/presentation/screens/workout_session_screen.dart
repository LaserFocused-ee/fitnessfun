import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/workout_session.dart';
import '../providers/workout_provider.dart';
import '../providers/workout_timer_provider.dart';
import '../widgets/info_chip.dart';
import '../widgets/video_player_dialog.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({
    super.key,
    required this.planId,
    this.sessionId,
    this.clientPlanId,
  });

  final String planId;
  final String? sessionId;
  final String? clientPlanId;

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSession();
    });
  }

  Future<void> _initSession() async {
    if (widget.sessionId != null) {
      await ref
          .read(activeWorkoutNotifierProvider.notifier)
          .loadSession(widget.sessionId!);
    } else {
      await ref.read(activeWorkoutNotifierProvider.notifier).startSession(
            planId: widget.planId,
            clientPlanId: widget.clientPlanId,
          );
    }
  }

  void _startRest(int? restMin, int? restMax, DateTime completedAt) {
    final minSeconds = restMin ?? 60;
    final maxSeconds = restMax ?? minSeconds + 30;
    ref.read(restTimerContextProvider.notifier).startRest(
      minSeconds: minSeconds,
      maxSeconds: maxSeconds,
      completedAt: completedAt,
    );
  }

  void _stopRest() {
    ref.read(restTimerContextProvider.notifier).stopRest();
  }

  void _showWorkoutCompleteDialog() {
    _stopRest(); // Stop any active rest timer

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.celebration, size: 48, color: Colors.green),
        title: const Text('Workout Complete!'),
        content: const Text('Great job! You finished all exercises.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _finishWorkout();
            },
            child: const Text('Finish & Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishWorkout() async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Workout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add any notes for this session:'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'How did it go? Any notes...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await ref
          .read(activeWorkoutNotifierProvider.notifier)
          .completeSession(notes: notesController.text.trim());

      if (mounted) {
        result.fold(
          (failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failure.displayMessage),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          },
          (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Workout completed! Great job!')),
            );
            context.pop();
          },
        );
      }
    }
  }

  void _showVideoModal(BuildContext context, String title, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(
        title: title,
        videoUrl: videoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeWorkoutNotifierProvider);
    final planAsync = ref.watch(planByIdProvider(widget.planId));
    final restTimer = ref.watch(globalRestTimerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return sessionAsync.when(
        data: (session) {
          if (session == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Workout')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final completedCount =
              session.exerciseLogs.where((l) => l.completed).length;
          final totalCount = session.exerciseLogs.length;
          final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

          // Get video URLs from plan
          final plan = planAsync.valueOrNull;
          final exerciseVideos = <String, String>{};
          if (plan != null) {
            for (final exercise in plan.exercises) {
              if (exercise.exerciseVideoUrl != null) {
                exerciseVideos[exercise.id] = exercise.exerciseVideoUrl!;
              }
            }
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
              title: Text(session.planName ?? 'Workout'),
            ),
            body: Column(
              children: [
                // Progress section
                Container(
                  color: colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completedCount of $totalCount exercises',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Exercise list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: session.exerciseLogs.length,
                    itemBuilder: (context, index) {
                      final log = session.exerciseLogs[index];
                      final videoUrl = exerciseVideos[log.planExerciseId];
                      return _ExerciseLogCard(
                        log: log,
                        index: index,
                        videoUrl: videoUrl,
                        isResting: restTimer.state != GlobalRestState.working,
                        onVideoTap: videoUrl != null
                            ? () => _showVideoModal(
                                context, log.exerciseName ?? 'Exercise', videoUrl)
                            : null,
                        onSetComplete: (updatedLog, isLastSet, completedAt) async {
                          await ref
                              .read(activeWorkoutNotifierProvider.notifier)
                              .updateExerciseLog(updatedLog);

                          // Start rest timer after completing a set
                          if (!isLastSet) {
                            _startRest(log.targetRestMin, log.targetRestMax, completedAt);
                          } else {
                            // Exercise complete - check if all exercises are now done
                            final currentSession = ref.read(activeWorkoutNotifierProvider).valueOrNull;
                            if (currentSession != null) {
                              final allComplete = currentSession.exerciseLogs.every((l) => l.completed);
                              if (allComplete) {
                                // All exercises complete - show completion dialog
                                _showWorkoutCompleteDialog();
                              } else {
                                // Start rest for next exercise
                                _startRest(log.targetRestMin, log.targetRestMax, completedAt);
                              }
                            }
                          }
                        },
                        onStartSet: () {
                          // User started next set, stop rest timer
                          _stopRest();
                        },
                        onUpdate: (updatedLog) async {
                          await ref
                              .read(activeWorkoutNotifierProvider.notifier)
                              .updateExerciseLog(updatedLog);
                        },
                      );
                    },
                  ),
                ),

                // Finish button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _finishWorkout,
                        icon: const Icon(Icons.check),
                        label: const Text('Finish Workout'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Starting Workout...')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Workout')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _ExerciseLogCard extends StatefulWidget {
  const _ExerciseLogCard({
    required this.log,
    required this.index,
    required this.onUpdate,
    required this.onSetComplete,
    required this.onStartSet,
    required this.isResting,
    this.videoUrl,
    this.onVideoTap,
  });

  final ExerciseLog log;
  final int index;
  final String? videoUrl;
  final VoidCallback? onVideoTap;
  final bool isResting;
  final void Function(ExerciseLog updatedLog, bool isLastSet, DateTime completedAt) onSetComplete;
  final VoidCallback onStartSet;
  final Future<void> Function(ExerciseLog) onUpdate;

  @override
  State<_ExerciseLogCard> createState() => _ExerciseLogCardState();
}

class _ExerciseLogCardState extends State<_ExerciseLogCard> {
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  late TextEditingController _notesController; // Exercise-level notes
  late TextEditingController _setNotesController; // Per-set notes for edit modal
  bool _isExpanded = false;

  int get _currentSetIndex {
    // Find the first incomplete set
    for (var i = 0; i < widget.log.setData.length; i++) {
      if (!widget.log.setData[i].completed) {
        return i;
      }
    }
    return widget.log.setData.length; // All complete
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final currentIndex = _currentSetIndex;
    if (currentIndex < widget.log.setData.length) {
      final setData = widget.log.setData[currentIndex];
      // Use actual logged value if exists, otherwise use target value
      _repsController = TextEditingController(
        text: setData.reps?.toString() ?? setData.targetReps?.toString() ?? '',
      );
      _weightController = TextEditingController(
        text: setData.weight?.toString() ?? setData.targetWeight?.toString() ?? '',
      );
    } else {
      _repsController = TextEditingController();
      _weightController = TextEditingController();
    }
    _notesController = TextEditingController(text: widget.log.notes ?? '');
    _setNotesController = TextEditingController();
  }

  @override
  void didUpdateWidget(_ExerciseLogCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if current set changed
    final oldIndex = _findCurrentSetIndex(oldWidget.log.setData);
    final newIndex = _currentSetIndex;

    if (oldIndex != newIndex && newIndex < widget.log.setData.length) {
      // Moving to new set, update controllers with target values
      final setData = widget.log.setData[newIndex];
      _repsController.text = setData.reps?.toString() ?? setData.targetReps?.toString() ?? '';
      _weightController.text = setData.weight?.toString() ?? setData.targetWeight?.toString() ?? '';
    }

    if (_notesController.text != (widget.log.notes ?? '')) {
      _notesController.text = widget.log.notes ?? '';
    }
  }

  int _findCurrentSetIndex(List<SetLog> setData) {
    for (var i = 0; i < setData.length; i++) {
      if (!setData[i].completed) {
        return i;
      }
    }
    return setData.length;
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    _setNotesController.dispose();
    super.dispose();
  }

  /// Complete set with target values (happy path - no inputs needed)
  void _onCompleteSetAsPlanned() {
    final currentIndex = _currentSetIndex;
    if (currentIndex >= widget.log.setData.length) return;

    widget.onStartSet(); // Stop rest timer

    final completedAt = DateTime.now().toUtc();
    final currentSet = widget.log.setData[currentIndex];

    final updatedSetData = List<SetLog>.from(widget.log.setData);
    updatedSetData[currentIndex] = currentSet.copyWith(
      reps: currentSet.targetReps,
      weight: currentSet.targetWeight,
      completed: true,
      completedAt: completedAt,
    );

    final isLastSet = currentIndex == widget.log.setData.length - 1;
    final allCompleted = updatedSetData.every((s) => s.completed);

    final updatedLog = widget.log.copyWith(
      setData: updatedSetData,
      completed: allCompleted,
    );

    widget.onSetComplete(updatedLog, isLastSet, completedAt);
  }

  /// Show modal to edit reps/weight/notes before completing
  void _showEditAndCompleteModal() {
    final currentIndex = _currentSetIndex;
    if (currentIndex >= widget.log.setData.length) return;

    final currentSet = widget.log.setData[currentIndex];

    // Pre-populate with target values
    _repsController.text = currentSet.targetReps?.toString() ?? '';
    _weightController.text = currentSet.targetWeight?.toString() ?? '';
    _setNotesController.text = currentSet.notes ?? '';

    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set ${currentIndex + 1} - Edit Values'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reps',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _setNotesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes for this set',
                hintText: 'e.g., felt easy, form issue, etc.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete Set'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _onCompleteSetWithEdits();
      }
    });
  }

  /// Complete set with edited values from modal
  void _onCompleteSetWithEdits() {
    final currentIndex = _currentSetIndex;
    if (currentIndex >= widget.log.setData.length) return;

    widget.onStartSet(); // Stop rest timer

    final completedAt = DateTime.now().toUtc();
    final currentSet = widget.log.setData[currentIndex];

    final updatedSetData = List<SetLog>.from(widget.log.setData);
    updatedSetData[currentIndex] = currentSet.copyWith(
      reps: _repsController.text.isEmpty
          ? currentSet.targetReps
          : int.tryParse(_repsController.text),
      weight: _weightController.text.isEmpty
          ? currentSet.targetWeight
          : double.tryParse(_weightController.text),
      notes: _setNotesController.text.isEmpty ? null : _setNotesController.text,
      completed: true,
      completedAt: completedAt,
    );

    final isLastSet = currentIndex == widget.log.setData.length - 1;
    final allCompleted = updatedSetData.every((s) => s.completed);

    final updatedLog = widget.log.copyWith(
      setData: updatedSetData,
      completed: allCompleted,
    );

    // Clear for next set
    _repsController.clear();
    _weightController.clear();
    _setNotesController.clear();

    widget.onSetComplete(updatedLog, isLastSet, completedAt);
  }

  void _onNotesChanged() {
    final updatedLog = widget.log.copyWith(
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );
    widget.onUpdate(updatedLog);
  }

  /// Build display string for current set target (e.g., "8-10 reps × 22kg")
  String _buildCurrentSetTargetDisplay() {
    final currentIndex = _currentSetIndex;
    if (currentIndex >= widget.log.setData.length) return '';

    final currentSet = widget.log.setData[currentIndex];
    final parts = <String>[];

    // Reps
    if (currentSet.targetReps != null) {
      if (currentSet.targetRepsMax != null &&
          currentSet.targetRepsMax != currentSet.targetReps) {
        parts.add('${currentSet.targetReps}-${currentSet.targetRepsMax} reps');
      } else {
        parts.add('${currentSet.targetReps} reps');
      }
    }

    // Weight
    if (currentSet.targetWeight != null) {
      parts.add('${currentSet.targetWeight}kg');
    }

    return parts.join(' × ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentSetIndex = _currentSetIndex;
    final isExerciseComplete = widget.log.completed;
    final totalSets = widget.log.setData.length;

    // Completed exercise - show collapsed or expanded
    if (isExerciseComplete) {
      if (_isExpanded) {
        return _buildExpandedCompletedCard(theme, colorScheme, totalSets);
      }
      return _buildCollapsedCard(theme, colorScheme, totalSets);
    }

    // Active exercise - show current set
    return _buildActiveCard(theme, colorScheme, currentSetIndex, totalSets);
  }

  Widget _buildCollapsedCard(
    ThemeData theme,
    ColorScheme colorScheme,
    int totalSets,
  ) {
    // Build summary of completed sets
    final completedSummary = widget.log.setData
        .map((s) => '${s.reps ?? "-"}×${s.weight ?? "-"}')
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.green.shade50,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = true),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
                child: const Icon(Icons.check, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.log.exerciseName ?? 'Exercise',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalSets sets: $completedSummary',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.videoUrl != null)
                IconButton(
                  icon: Icon(
                    Icons.play_circle_outline,
                    color: Colors.green.shade600,
                    size: 24,
                  ),
                  tooltip: 'Watch Demo',
                  onPressed: widget.onVideoTap,
                  visualDensity: VisualDensity.compact,
                ),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.green.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedCompletedCard(
    ThemeData theme,
    ColorScheme colorScheme,
    int totalSets,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with collapse button
            InkWell(
              onTap: () => setState(() => _isExpanded = false),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                    child: const Icon(Icons.check, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.log.exerciseName ?? 'Exercise',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  if (widget.videoUrl != null)
                    IconButton(
                      icon: Icon(
                        Icons.play_circle_filled,
                        color: Colors.green.shade600,
                        size: 32,
                      ),
                      tooltip: 'Watch Demo',
                      onPressed: widget.onVideoTap,
                    ),
                  Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.green.shade600,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // All sets (editable)
            ...List.generate(widget.log.setData.length, (i) {
              final setLog = widget.log.setData[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Set number
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.green,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Reps display/input
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: TextEditingController(text: setLog.reps?.toString() ?? ''),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.green.shade800),
                        decoration: InputDecoration(
                          hintText: '-',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.green.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.green.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) => _updateSetData(i, reps: int.tryParse(value)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('×', style: TextStyle(color: Colors.green.shade700)),
                    const SizedBox(width: 4),
                    // Weight display/input
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: TextEditingController(text: setLog.weight?.toString() ?? ''),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.green.shade800),
                        decoration: InputDecoration(
                          hintText: 'kg',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.green.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.green.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) => _updateSetData(i, weight: double.tryParse(value)),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            // Notes field
            TextField(
              controller: _notesController,
              maxLines: 1,
              style: TextStyle(fontSize: 14, color: Colors.green.shade800),
              decoration: InputDecoration(
                hintText: 'Notes...',
                hintStyle: TextStyle(color: Colors.green.shade400),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green.shade300),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (_) => _onNotesChanged(),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSetData(int setIndex, {int? reps, double? weight}) {
    final updatedSetData = List<SetLog>.from(widget.log.setData);
    updatedSetData[setIndex] = updatedSetData[setIndex].copyWith(
      reps: reps ?? updatedSetData[setIndex].reps,
      weight: weight ?? updatedSetData[setIndex].weight,
    );
    final updatedLog = widget.log.copyWith(setData: updatedSetData);
    widget.onUpdate(updatedLog);
  }

  Widget _buildActiveCard(
    ThemeData theme,
    ColorScheme colorScheme,
    int currentSetIndex,
    int totalSets,
  ) {
    // Get completed sets for summary
    final completedSets = widget.log.setData
        .where((s) => s.completed)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                    border: Border.all(color: colorScheme.primary),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.log.exerciseName ?? 'Exercise',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.videoUrl != null)
                  IconButton(
                    icon: Icon(
                      Icons.play_circle_filled,
                      color: colorScheme.primary,
                      size: 32,
                    ),
                    tooltip: 'Watch Demo',
                    onPressed: widget.onVideoTap,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Target info chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.log.targetSets > 0)
                  InfoChip(
                    label: '${widget.log.targetSets} sets',
                    color: colorScheme.primaryContainer,
                  ),
                if (widget.log.targetRepsDisplay != null)
                  InfoChip(
                    label: '${widget.log.targetRepsDisplay} reps',
                    color: colorScheme.secondaryContainer,
                  ),
                if (widget.log.targetTempo != null)
                  InfoChip(
                    label: 'Tempo: ${widget.log.targetTempo}',
                    color: colorScheme.tertiaryContainer,
                  ),
                if (widget.log.targetRestDisplay != null)
                  InfoChip(
                    label: 'Rest: ${widget.log.targetRestDisplay}',
                    color: colorScheme.surfaceContainerHighest,
                  ),
              ],
            ),

            // Completed sets summary
            if (completedSets.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: completedSets.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final reps = s.reps ?? s.targetReps ?? '-';
                  final weight = s.weight ?? s.targetWeight ?? '-';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${i + 1}: $reps×${weight}kg',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Current set indicator and target values
            Row(
              children: [
                Text(
                  'Set ${currentSetIndex + 1} of $totalSets',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                // Target values display
                if (currentSetIndex < widget.log.setData.length) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _buildCurrentSetTargetDisplay(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Two action buttons
            Row(
              children: [
                // Primary: Complete as planned
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _onCompleteSetAsPlanned,
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('Complete Set'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Secondary: Edit and complete
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showEditAndCompleteModal,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Notes field (collapsed, expand on tap)
            TextField(
              controller: _notesController,
              maxLines: 1,
              style: const TextStyle(fontSize: 14),
              onChanged: (_) => _onNotesChanged(),
              decoration: InputDecoration(
                hintText: 'Add notes...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
