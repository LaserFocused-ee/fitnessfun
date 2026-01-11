import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/workout_repository_impl.dart';
import '../../domain/entities/workout_plan.dart';
import '../../domain/repositories/workout_repository.dart';

part 'workout_provider.g.dart';

/// Provides the WorkoutRepository instance
@riverpod
WorkoutRepository workoutRepository(WorkoutRepositoryRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabaseWorkoutRepository(supabase);
}

/// Provides all plans for the current trainer
@riverpod
Future<List<WorkoutPlan>> trainerPlans(TrainerPlansRef ref) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (profile == null) {
    return [];
  }

  final result = await repo.getPlansByTrainer(profile.id);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (plans) => plans,
  );
}

/// Provides a single plan by ID with exercises
@riverpod
Future<WorkoutPlan> planById(PlanByIdRef ref, String planId) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final result = await repo.getPlanById(planId);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (plan) => plan,
  );
}

/// Provides client plans for the current user (when they're a client)
@riverpod
Future<List<ClientPlan>> clientPlans(ClientPlansRef ref) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (profile == null) {
    return [];
  }

  final result = await repo.getClientPlans(profile.id);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (plans) => plans,
  );
}

/// Provides the active plan for a client
@riverpod
Future<ClientPlan?> activeClientPlan(ActiveClientPlanRef ref) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (profile == null) {
    return null;
  }

  final result = await repo.getActiveClientPlan(profile.id);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (plan) => plan,
  );
}

/// Notifier for creating/editing workout plans
@riverpod
class PlanFormNotifier extends _$PlanFormNotifier {
  @override
  WorkoutPlan build() {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    return WorkoutPlan.empty(trainerId: profile?.id ?? '');
  }

  void loadPlan(WorkoutPlan plan) {
    state = plan;
  }

  void setName(String name) {
    state = state.copyWith(name: name);
  }

  void setDescription(String? description) {
    state = state.copyWith(description: description);
  }

  void addExercise(PlanExercise exercise) {
    final exercises = [...state.exercises, exercise];
    state = state.copyWith(exercises: exercises);
  }

  void updateExercise(int index, PlanExercise exercise) {
    final exercises = [...state.exercises];
    exercises[index] = exercise;
    state = state.copyWith(exercises: exercises);
  }

  void removeExercise(int index) {
    final exercises = [...state.exercises];
    exercises.removeAt(index);
    // Reorder remaining exercises
    for (int i = 0; i < exercises.length; i++) {
      exercises[i] = exercises[i].copyWith(orderIndex: i);
    }
    state = state.copyWith(exercises: exercises);
  }

  void reorderExercises(int oldIndex, int newIndex) {
    final exercises = [...state.exercises];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = exercises.removeAt(oldIndex);
    exercises.insert(newIndex, item);
    // Update order indices
    for (int i = 0; i < exercises.length; i++) {
      exercises[i] = exercises[i].copyWith(orderIndex: i);
    }
    state = state.copyWith(exercises: exercises);
  }

  void reset() {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    state = WorkoutPlan.empty(trainerId: profile?.id ?? '');
  }

  Future<Either<Failure, WorkoutPlan>> save() async {
    final repo = ref.read(workoutRepositoryProvider);

    if (state.id.isEmpty) {
      // Create new plan
      final planResult = await repo.createPlan(state);

      return planResult.fold(
        (failure) => left(failure),
        (plan) async {
          // Add exercises to the plan
          for (final exercise in state.exercises) {
            final exerciseWithPlanId = exercise.copyWith(planId: plan.id);
            await repo.addExerciseToPlan(exerciseWithPlanId);
          }

          // Reload the plan with exercises
          return repo.getPlanById(plan.id);
        },
      );
    } else {
      // Update existing plan
      final planResult = await repo.updatePlan(state);

      return planResult.fold(
        (failure) => left(failure),
        (plan) async {
          // For simplicity, we'll delete and re-add all exercises
          // In production, you'd want to diff and update only changed exercises
          final existingPlan = await repo.getPlanById(plan.id);

          return existingPlan.fold(
            (failure) => left(failure),
            (existing) async {
              // Remove old exercises
              for (final exercise in existing.exercises) {
                await repo.removeExerciseFromPlan(exercise.id);
              }

              // Add new exercises
              for (final exercise in state.exercises) {
                final exerciseWithPlanId = exercise.copyWith(planId: plan.id);
                await repo.addExerciseToPlan(exerciseWithPlanId);
              }

              return repo.getPlanById(plan.id);
            },
          );
        },
      );
    }
  }

  Future<Either<Failure, Unit>> delete() async {
    if (state.id.isEmpty) {
      return left(
          const ValidationFailure(message: 'Cannot delete unsaved plan'));
    }

    final repo = ref.read(workoutRepositoryProvider);
    return repo.deletePlan(state.id);
  }
}

/// Notifier for assigning plans to clients
@riverpod
class PlanAssignmentNotifier extends _$PlanAssignmentNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<Either<Failure, ClientPlan>> assignToClient({
    required String planId,
    required String clientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncLoading();

    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.assignPlanToClient(
      planId: planId,
      clientId: clientId,
      startDate: startDate,
      endDate: endDate,
    );

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    return result;
  }
}
