import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/exercise_provider.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
  });

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(exerciseByIdProvider(exerciseId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return exerciseAsync.when(
      data: (exercise) {
        return Scaffold(
          appBar: AppBar(
            title: Text(exercise.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.push('/trainer/exercises/$exerciseId/edit'),
                tooltip: 'Edit',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video preview card
                if (exercise.videoUrl != null) ...[
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        final uri = Uri.tryParse(exercise.videoUrl!);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        color: colorScheme.surfaceContainerHighest,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_filled,
                              size: 64,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Watch Video Demo',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Info section
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (exercise.muscleGroup != null)
                      Chip(
                        avatar: const Icon(Icons.fitness_center, size: 18),
                        label: Text(exercise.muscleGroup!),
                        backgroundColor: colorScheme.secondaryContainer,
                      ),
                    if (exercise.tempo != null && exercise.tempo!.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.speed, size: 18),
                        label: Text('Tempo: ${exercise.tempo}'),
                        backgroundColor: colorScheme.primaryContainer,
                      ),
                    if (exercise.isGlobal)
                      Chip(
                        avatar: const Icon(Icons.public, size: 18),
                        label: const Text('Global'),
                        backgroundColor: colorScheme.tertiaryContainer,
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // Instructions
                Text(
                  'Instructions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    exercise.instructions?.isNotEmpty == true
                        ? exercise.instructions!
                        : 'No instructions provided.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: exercise.instructions?.isNotEmpty == true
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Video URL (if present)
                if (exercise.videoUrl != null) ...[
                  Text(
                    'Video Link',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final uri = Uri.tryParse(exercise.videoUrl!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    child: Text(
                      exercise.videoUrl!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Exercise')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Exercise')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Error loading exercise: $error'),
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
