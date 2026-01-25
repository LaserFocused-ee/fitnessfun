import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../../app/routes.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/services/video_cache_service.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../domain/entities/workout_plan.dart';
import '../providers/plan_export_provider.dart';
import '../providers/workout_provider.dart';

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({
    super.key,
    required this.planId,
    this.clientId,
    this.isClientView = false,
  });

  final String planId;
  final String? clientId;
  final bool isClientView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planByIdProvider(planId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return planAsync.when(
      data: (plan) {
        return Scaffold(
          appBar: AppBar(
            leading: AppBackButton(
              fallbackRoute: isClientView ? AppRoutes.myPlans : AppRoutes.home,
            ),
            title: Text(plan.name),
            actions: [
              // Trainer-only actions
              if (!isClientView) ...[
                if (clientId != null)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.push('/plans/$planId/edit?clientId=$clientId'),
                    tooltip: 'Edit Plan',
                  ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'export',
                      child: ListTile(
                        leading: Icon(Icons.download),
                        title: Text('Export to Excel'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'assign',
                      child: ListTile(
                        leading: Icon(Icons.person_add),
                        title: Text('Assign to Client'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete Plan'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'export') {
                      await _exportPlan(context, ref, plan);
                    } else if (value == 'delete') {
                      await _deletePlan(context, ref);
                    } else if (value == 'assign') {
                      _showAssignDialog(context, ref);
                    }
                  },
                ),
              ],
            ],
          ),
          // Client: Start Workout FAB
          floatingActionButton: isClientView
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/client/plans/$planId/workout'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Workout'),
                )
              : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              if (plan.description != null && plan.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            plan.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Exercises header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Exercises (${plan.exercises.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Exercise list
              Expanded(
                child: plan.exercises.isEmpty
                    ? Center(
                        child: Text(
                          'No exercises in this plan',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: plan.exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = plan.exercises[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            colorScheme.primaryContainer,
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          exercise.exerciseName ??
                                              'Unknown Exercise',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      // Video button
                                      if (exercise.exerciseVideoUrl != null)
                                        IconButton(
                                          icon: Icon(
                                            Icons.play_circle_filled,
                                            color: colorScheme.primary,
                                            size: 32,
                                          ),
                                          tooltip: 'Watch Demo',
                                          onPressed: () => _showVideoModal(
                                            context,
                                            exercise.exerciseName ?? 'Exercise',
                                            exercise.exerciseVideoUrl!,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (exercise.sets.isNotEmpty) ...[
                                        _InfoChip(
                                          label: '${exercise.sets.length} sets',
                                          color: colorScheme.primaryContainer,
                                        ),
                                        _InfoChip(
                                          label: _buildRepsLabel(exercise),
                                          color: colorScheme.secondaryContainer,
                                        ),
                                      ],
                                      // Show exercise tempo (prefer exerciseTempo, fall back to tempo for backward compatibility)
                                      if (exercise.exerciseTempo != null ||
                                          exercise.tempo != null)
                                        _InfoChip(
                                          label: 'Tempo: ${exercise.exerciseTempo ?? exercise.tempo}',
                                          color: colorScheme.tertiaryContainer,
                                        ),
                                      if (exercise.restMin != null)
                                        _InfoChip(
                                          label: _buildRestLabel(exercise),
                                          color: colorScheme.surfaceContainerHighest,
                                        ),
                                    ],
                                  ),
                                  // Exercise notes (from the exercise itself)
                                  if (exercise.exerciseNotes != null &&
                                      exercise.exerciseNotes!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 16,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              exercise.exerciseNotes!,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color:
                                                    colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // Additional client-specific notes
                                  if (exercise.notes != null &&
                                      exercise.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.note_outlined,
                                            size: 16,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              exercise.notes!,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: colorScheme.onSurface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: AppBackButton(
            fallbackRoute: isClientView ? AppRoutes.myPlans : AppRoutes.home,
          ),
          title: const Text('Plan'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: AppBackButton(
            fallbackRoute: isClientView ? AppRoutes.myPlans : AppRoutes.home,
          ),
          title: const Text('Plan'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 8),
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

  Future<void> _deletePlan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: const Text(
          'Are you sure you want to delete this plan? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.deletePlan(planId);

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
        ref.invalidate(trainerPlansProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan deleted')),
        );
        context.pop();
      },
    );
  }

  void _showAssignDialog(BuildContext context, WidgetRef ref) {
    // TODO: Implement client assignment dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Client assignment coming soon - need trainer-client linking first'),
      ),
    );
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

  Future<void> _exportPlan(
    BuildContext context,
    WidgetRef ref,
    WorkoutPlan plan,
  ) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Exporting...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    final result = await ref.read(planExportNotifierProvider.notifier).exportPlan(plan);

    if (!context.mounted) return;

    // Clear the loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.displayMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
      (fileName) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported: $fileName'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      },
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
            // Header
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
            // Video player
            Flexible(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: _VideoPlayer(videoUrl: widget.videoUrl),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cross-platform video player with caching and download progress
class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({required this.videoUrl});

  final String videoUrl;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  // Download state
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
      // On mobile, use file path; on web, use URL
      if (kIsWeb) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(videoPath));
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
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
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
    final colorScheme = Theme.of(context).colorScheme;

    // Show download progress
    if (_isDownloading) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      color: colorScheme.primary,
                      strokeWidth: 4,
                    ),
                    if (_downloadProgress > 0)
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _downloadProgress > 0 ? 'Downloading...' : 'Loading...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show initialization spinner
    if (_isInitializing) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Preparing video...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    // Show error
    if (_error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: colorScheme.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load video',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show video player
    return ColoredBox(
      color: Colors.black,
      child: _chewieController != null
          ? Chewie(controller: _chewieController!)
          : const SizedBox.shrink(),
    );
  }
}

/// Build reps label from exercise sets (shows first set's reps range)
String _buildRepsLabel(dynamic exercise) {
  if ((exercise.sets as List).isEmpty) return '';
  final firstSet = exercise.sets.first;
  if (firstSet.repsMax != null && firstSet.repsMax != firstSet.reps) {
    return '${firstSet.reps}-${firstSet.repsMax} reps';
  }
  return '${firstSet.reps} reps';
}

/// Build rest label from exercise rest range
String _buildRestLabel(dynamic exercise) {
  if (exercise.restMin == null) return '';
  if (exercise.restMax != null && exercise.restMax != exercise.restMin) {
    return 'Rest: ${exercise.restMin}-${exercise.restMax}s';
  }
  return 'Rest: ${exercise.restMin}s';
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
