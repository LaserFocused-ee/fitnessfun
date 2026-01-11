import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/exercise.dart';
import '../providers/exercise_provider.dart';
import '../widgets/exercise_card.dart';
import '../widgets/muscle_group_filter.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(filteredExercisesProvider);
    final filter = ref.watch(exerciseFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/trainer/exercises/create'),
            tooltip: 'Add Exercise',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(exerciseFilterProvider.notifier)
                              .setSearchQuery(null);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                ref
                    .read(exerciseFilterProvider.notifier)
                    .setSearchQuery(value.isEmpty ? null : value);
              },
            ),
          ),

          // Muscle group filter chips
          MuscleGroupFilter(
            selectedGroup: filter.muscleGroup,
            onSelected: (group) {
              ref.read(exerciseFilterProvider.notifier).setMuscleGroup(group);
            },
          ),

          const Divider(),

          // Exercise list
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                if (exercises.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          filter.muscleGroup != null || filter.searchQuery != null
                              ? 'No exercises match your filters'
                              : 'No exercises yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                        if (filter.muscleGroup != null ||
                            filter.searchQuery != null) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(exerciseFilterProvider.notifier)
                                  .clearFilters();
                            },
                            child: const Text('Clear filters'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return ExerciseCard(
                      exercise: exercise,
                      onTap: () => context.push(
                        '/trainer/exercises/${exercise.id}',
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(filteredExercisesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
