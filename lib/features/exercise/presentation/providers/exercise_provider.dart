import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/error/failures.dart';
import '../../data/repositories/exercise_repository_impl.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';

part 'exercise_provider.g.dart';

/// Provides the ExerciseRepository instance
@riverpod
ExerciseRepository exerciseRepository(ExerciseRepositoryRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabaseExerciseRepository(supabase);
}

/// Provides all exercises with optional filtering
@riverpod
Future<List<Exercise>> exercises(
  ExercisesRef ref, {
  String? muscleGroup,
  String? searchQuery,
}) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  final result = await repo.getExercises(
    muscleGroup: muscleGroup,
    searchQuery: searchQuery,
  );

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (exercises) => exercises,
  );
}

/// Filter state for the exercise library
@riverpod
class ExerciseFilter extends _$ExerciseFilter {
  @override
  ExerciseFilterState build() => const ExerciseFilterState();

  void setMuscleGroup(String? muscleGroup) {
    state = state.copyWith(muscleGroup: muscleGroup);
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearFilters() {
    state = const ExerciseFilterState();
  }
}

/// Filter state model
class ExerciseFilterState {
  const ExerciseFilterState({
    this.muscleGroup,
    this.searchQuery,
  });

  final String? muscleGroup;
  final String? searchQuery;

  ExerciseFilterState copyWith({
    String? muscleGroup,
    String? searchQuery,
  }) {
    return ExerciseFilterState(
      muscleGroup: muscleGroup ?? this.muscleGroup,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Filtered exercises based on current filter state
@riverpod
Future<List<Exercise>> filteredExercises(FilteredExercisesRef ref) async {
  final filter = ref.watch(exerciseFilterProvider);
  final repo = ref.watch(exerciseRepositoryProvider);

  final result = await repo.getExercises(
    muscleGroup: filter.muscleGroup,
    searchQuery: filter.searchQuery,
  );

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (exercises) => exercises,
  );
}

/// Provides a single exercise by ID
@riverpod
Future<Exercise> exerciseById(ExerciseByIdRef ref, String id) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  final result = await repo.getExerciseById(id);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (exercise) => exercise,
  );
}

/// Notifier for exercise form (create/edit)
@riverpod
class ExerciseFormNotifier extends _$ExerciseFormNotifier {
  @override
  Exercise build() => Exercise.empty();

  void setName(String name) {
    state = state.copyWith(name: name);
  }

  void setInstructions(String? instructions) {
    state = state.copyWith(instructions: instructions);
  }

  void setVideoPath(String? videoPath) {
    state = state.copyWith(videoPath: videoPath);
  }

  void setMuscleGroup(String? muscleGroup) {
    state = state.copyWith(muscleGroup: muscleGroup);
  }

  void loadExercise(Exercise exercise) {
    state = exercise;
  }

  void reset() {
    state = Exercise.empty();
  }

  Future<Either<Failure, Exercise>> save() async {
    final repo = ref.read(exerciseRepositoryProvider);

    if (state.id.isEmpty) {
      return repo.createExercise(state);
    } else {
      return repo.updateExercise(state);
    }
  }

  Future<Either<Failure, Unit>> delete() async {
    if (state.id.isEmpty) {
      return left(
        const ValidationFailure(message: 'Cannot delete unsaved exercise'),
      );
    }

    final repo = ref.read(exerciseRepositoryProvider);
    return repo.deleteExercise(state.id);
  }
}
