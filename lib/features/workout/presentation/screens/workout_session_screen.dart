import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/services/video_cache_service.dart';
import '../../domain/entities/workout_session.dart';
import '../providers/workout_provider.dart';

/// Rest timer states
enum RestState { working, resting, ready, go }

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
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  // Rest timer state
  RestState _restState = RestState.working;
  Duration _restElapsed = Duration.zero;
  int _restMinSeconds = 0;
  int _restMaxSeconds = 0;

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

    final session = ref.read(activeWorkoutNotifierProvider).valueOrNull;
    if (session != null) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed += const Duration(seconds: 1);

          // Update rest timer if resting
          if (_restState != RestState.working) {
            _restElapsed += const Duration(seconds: 1);
            _updateRestState();
          }
        });
      }
    });
  }

  void _updateRestState() {
    final restSeconds = _restElapsed.inSeconds;

    if (restSeconds >= _restMaxSeconds) {
      _restState = RestState.go;
    } else if (restSeconds >= _restMinSeconds) {
      _restState = RestState.ready;
    } else {
      _restState = RestState.resting;
    }
  }

  void _startRest(String? restString) {
    // Parse rest string like "90" or "90-120"
    final parsed = _parseRestRange(restString);
    _restMinSeconds = parsed.$1;
    _restMaxSeconds = parsed.$2;
    _restElapsed = Duration.zero;
    _restState = RestState.resting;
  }

  void _stopRest() {
    _restState = RestState.working;
    _restElapsed = Duration.zero;
  }

  (int, int) _parseRestRange(String? restString) {
    if (restString == null || restString.isEmpty) {
      return (60, 90); // Default rest
    }

    // Handle range format "90-120" or single value "90"
    if (restString.contains('-')) {
      final parts = restString.split('-');
      final min = int.tryParse(parts[0].trim()) ?? 60;
      final max = int.tryParse(parts[1].trim()) ?? 90;
      return (min, max);
    } else {
      final value = int.tryParse(restString.trim()) ?? 60;
      return (value, value + 30); // Add 30s buffer for single values
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor(ColorScheme colorScheme) {
    switch (_restState) {
      case RestState.working:
        return colorScheme.primary; // Green-ish (primary)
      case RestState.resting:
        return Colors.orange;
      case RestState.ready:
        return Colors.blue;
      case RestState.go:
        return Colors.green;
    }
  }

  Color _getTimerBackgroundColor(ColorScheme colorScheme) {
    switch (_restState) {
      case RestState.working:
        return colorScheme.primaryContainer;
      case RestState.resting:
        return Colors.orange.shade100;
      case RestState.ready:
        return Colors.blue.shade100;
      case RestState.go:
        return Colors.green.shade100;
    }
  }

  String _getTimerLabel() {
    switch (_restState) {
      case RestState.working:
        return '';
      case RestState.resting:
        return 'REST ';
      case RestState.ready:
        return 'READY ';
      case RestState.go:
        return 'GO! ';
    }
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

  Future<void> _cancelWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Workout'),
        content: const Text(
          'Are you sure you want to cancel this workout? All logged exercises will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel Workout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(activeWorkoutNotifierProvider.notifier).cancelSession();
      if (mounted) {
        context.pop();
      }
    }
  }

  void _showVideoModal(BuildContext context, String title, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => _VideoPlayerDialog(
        title: title,
        videoUrl: videoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeWorkoutNotifierProvider);
    final planAsync = ref.watch(planByIdProvider(widget.planId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _cancelWorkout();
      },
      child: sessionAsync.when(
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

          final timerColor = _getTimerColor(colorScheme);
          final timerBgColor = _getTimerBackgroundColor(colorScheme);
          final timerLabel = _getTimerLabel();

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelWorkout,
              ),
              title: Text(session.planName ?? 'Workout'),
              actions: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: timerBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer,
                        size: 18,
                        color: timerColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$timerLabel${_formatDuration(_elapsed)}',
                        style: TextStyle(
                          color: timerColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                        isResting: _restState != RestState.working,
                        onVideoTap: videoUrl != null
                            ? () => _showVideoModal(
                                context, log.exerciseName ?? 'Exercise', videoUrl)
                            : null,
                        onSetComplete: (updatedLog, isLastSet) {
                          ref
                              .read(activeWorkoutNotifierProvider.notifier)
                              .updateExerciseLog(updatedLog);

                          // Start rest timer after completing a set (unless it's the last set of the exercise)
                          if (!isLastSet) {
                            _startRest(log.targetRest);
                          } else {
                            // Exercise complete - start rest for next exercise
                            _startRest(log.targetRest);
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
  final void Function(ExerciseLog updatedLog, bool isLastSet) onSetComplete;
  final VoidCallback onStartSet;
  final Future<void> Function(ExerciseLog) onUpdate;

  @override
  State<_ExerciseLogCard> createState() => _ExerciseLogCardState();
}

class _ExerciseLogCardState extends State<_ExerciseLogCard> {
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  late TextEditingController _notesController;
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
      _repsController = TextEditingController(
        text: widget.log.setData[currentIndex].reps ?? '',
      );
      _weightController = TextEditingController(
        text: widget.log.setData[currentIndex].weight ?? '',
      );
    } else {
      _repsController = TextEditingController();
      _weightController = TextEditingController();
    }
    _notesController = TextEditingController(text: widget.log.notes ?? '');
  }

  @override
  void didUpdateWidget(_ExerciseLogCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if current set changed
    final oldIndex = _findCurrentSetIndex(oldWidget.log.setData);
    final newIndex = _currentSetIndex;

    if (oldIndex != newIndex && newIndex < widget.log.setData.length) {
      // Moving to new set, update controllers
      _repsController.text = widget.log.setData[newIndex].reps ?? '';
      _weightController.text = widget.log.setData[newIndex].weight ?? '';
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
    super.dispose();
  }

  void _onCompleteSet() {
    final currentIndex = _currentSetIndex;
    if (currentIndex >= widget.log.setData.length) return;

    widget.onStartSet(); // Stop rest timer when interacting

    final updatedSetData = List<SetLog>.from(widget.log.setData);
    updatedSetData[currentIndex] = updatedSetData[currentIndex].copyWith(
      reps: _repsController.text.isEmpty ? null : _repsController.text,
      weight: _weightController.text.isEmpty ? null : _weightController.text,
      completed: true,
    );

    final isLastSet = currentIndex == widget.log.setData.length - 1;
    final allCompleted = updatedSetData.every((s) => s.completed);

    final updatedLog = widget.log.copyWith(
      setData: updatedSetData,
      completed: allCompleted,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    // Clear inputs for next set
    if (!isLastSet) {
      _repsController.clear();
      _weightController.clear();
    }

    widget.onSetComplete(updatedLog, isLastSet);
  }

  void _onNotesChanged() {
    final updatedLog = widget.log.copyWith(
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );
    widget.onUpdate(updatedLog);
  }

  void _onInputFocus() {
    widget.onStartSet(); // Stop rest timer when user starts typing
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
                        controller: TextEditingController(text: setLog.reps ?? ''),
                        keyboardType: TextInputType.text,
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
                        onChanged: (value) => _updateSetData(i, reps: value),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('×', style: TextStyle(color: Colors.green.shade700)),
                    const SizedBox(width: 4),
                    // Weight display/input
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: TextEditingController(text: setLog.weight ?? ''),
                        keyboardType: TextInputType.text,
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
                        onChanged: (value) => _updateSetData(i, weight: value),
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

  void _updateSetData(int setIndex, {String? reps, String? weight}) {
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
                if (widget.log.targetReps != null)
                  _InfoChip(
                    label: '${widget.log.targetReps} reps',
                    color: colorScheme.secondaryContainer,
                  ),
                if (widget.log.targetTempo != null)
                  _InfoChip(
                    label: 'Tempo: ${widget.log.targetTempo}',
                    color: colorScheme.tertiaryContainer,
                  ),
                if (widget.log.targetRest != null)
                  _InfoChip(
                    label: 'Rest: ${widget.log.targetRest}s',
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
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${i + 1}: ${s.reps ?? "-"}×${s.weight ?? "-"}',
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

            // Current set indicator
            Text(
              'Set ${currentSetIndex + 1} of $totalSets',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),

            const SizedBox(height: 12),

            // Current set input row
            Row(
              children: [
                // Reps input
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.text,
                    textAlign: TextAlign.center,
                    onTap: _onInputFocus,
                    decoration: InputDecoration(
                      labelText: 'Reps',
                      hintText: widget.log.targetReps ?? '10',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Weight input
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.text,
                    textAlign: TextAlign.center,
                    onTap: _onInputFocus,
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      hintText: 'kg',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Complete button
                FilledButton.icon(
                  onPressed: _onCompleteSet,
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('Done'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Notes field
            TextField(
              controller: _notesController,
              maxLines: 1,
              onTap: _onInputFocus,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Notes...',
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
              onChanged: (_) => _onNotesChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({
    required this.title,
    required this.videoUrl,
  });

  final String title;
  final String videoUrl;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isDownloading = true;
  double _downloadProgress = 0.0;
  bool _isInitializing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _downloadAndPlay();
  }

  Future<void> _downloadAndPlay() async {
    final cacheService = VideoCacheService.instance;

    await for (final state in cacheService.getVideo(widget.videoUrl)) {
      if (!mounted) return;

      switch (state) {
        case VideoDownloading(progress: final progress):
          setState(() {
            _isDownloading = true;
            _downloadProgress = progress;
          });
        case VideoCompleted(path: final path):
          setState(() {
            _isDownloading = false;
            _isInitializing = true;
          });
          await _initializePlayer(path);
        case VideoError(message: final message):
          setState(() {
            _isDownloading = false;
            _error = message;
          });
      }
    }
  }

  Future<void> _initializePlayer(String videoPath) async {
    try {
      if (kIsWeb) {
        _videoController =
            VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else {
        _videoController = VideoPlayerController.file(File(videoPath));
      }

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        showControls: true,
        aspectRatio: _videoController!.value.aspectRatio,
      );

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.9,
          maxHeight: screenSize.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: _buildVideoContent(colorScheme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent(ColorScheme colorScheme) {
    if (_isDownloading) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  color: colorScheme.primary,
                ),
              ),
              if (_downloadProgress > 0) ...[
                const SizedBox(height: 16),
                Text(
                  '${(_downloadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_isInitializing) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load video',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: _chewieController != null
          ? Chewie(controller: _chewieController!)
          : const SizedBox.shrink(),
    );
  }
}
