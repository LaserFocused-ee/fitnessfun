import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../clients/presentation/providers/client_provider.dart';
import '../../data/repositories/workout_repository_impl.dart';
import '../../domain/entities/workout_plan.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/repositories/workout_repository.dart';
import 'workout_timer_provider.dart';

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

/// Provides all client plans for the current user (when they're a client)
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

/// Provides client plans filtered by the primary (active) trainer
@riverpod
Future<List<ClientPlan>> clientPlansForPrimaryTrainer(
    ClientPlansForPrimaryTrainerRef ref) async {
  final allPlans = await ref.watch(clientPlansProvider.future);
  final primaryTrainer = await ref.watch(primaryTrainerProvider.future);

  // If no primary trainer is set, show no plans (user needs to select a trainer)
  if (primaryTrainer == null) {
    return [];
  }

  // Filter plans to only show those from the primary trainer
  return allPlans
      .where((plan) => plan.trainerId == primaryTrainer.trainerId)
      .toList();
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

// ===== Workout Sessions =====

/// Provides client's workout session history
@riverpod
Future<List<WorkoutSession>> clientWorkoutHistory(
  ClientWorkoutHistoryRef ref, {
  int limit = 50,
}) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (profile == null) {
    return [];
  }

  final result = await repo.getClientWorkoutSessions(profile.id, limit: limit);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (sessions) => sessions,
  );
}

/// Provides a single workout session by ID
@riverpod
Future<WorkoutSession> workoutSessionById(
  WorkoutSessionByIdRef ref,
  String sessionId,
) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final result = await repo.getWorkoutSession(sessionId);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (session) => session,
  );
}

/// Notifier for managing an active workout session
/// Made keepAlive to persist across navigation and page refreshes
@Riverpod(keepAlive: true)
class ActiveWorkoutNotifier extends _$ActiveWorkoutNotifier {
  @override
  AsyncValue<WorkoutSession?> build() => const AsyncData(null);

  /// Check for and restore any active session on startup
  Future<void> checkAndRestoreActiveSession() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;

    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.getActiveSession(profile.id);

    result.fold(
      (failure) => null, // Silently fail - not critical
      (session) {
        if (session != null) {
          state = AsyncData(session);
          // Restore rest timer context from last completed set
          ref.read(restTimerContextProvider.notifier).restoreFromSession(session);
        }
      },
    );
  }

  /// Start a new workout session from a plan
  Future<Either<Failure, WorkoutSession>> startSession({
    required String planId,
    String? clientPlanId,
  }) async {
    state = const AsyncLoading();

    final repo = ref.read(workoutRepositoryProvider);
    final profile = ref.read(currentProfileProvider).valueOrNull;

    if (profile == null) {
      state = const AsyncData(null);
      return left(const AuthFailure(message: 'Not authenticated'));
    }

    final result = await repo.startWorkoutSession(
      clientId: profile.id,
      planId: planId,
      clientPlanId: clientPlanId,
    );

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (session) => AsyncData(session),
    );

    return result;
  }

  /// Load an existing session (for resuming)
  Future<void> loadSession(String sessionId) async {
    state = const AsyncLoading();

    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.getWorkoutSession(sessionId);

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (session) => AsyncData(session),
    );
  }

  /// Update an exercise log (mark complete, add notes, etc.)
  Future<Either<Failure, ExerciseLog>> updateExerciseLog(
    ExerciseLog log,
  ) async {
    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.updateExerciseLog(log);

    result.fold(
      (failure) => null,
      (updatedLog) {
        // Update the session state with the new log
        final currentSession = state.valueOrNull;
        if (currentSession != null) {
          final updatedLogs = currentSession.exerciseLogs.map((l) {
            return l.id == updatedLog.id ? log : l;
          }).toList();
          state = AsyncData(currentSession.copyWith(exerciseLogs: updatedLogs));
        }
      },
    );

    return result;
  }

  /// Complete the workout session
  Future<Either<Failure, WorkoutSession>> completeSession({
    String? notes,
  }) async {
    final currentSession = state.valueOrNull;
    if (currentSession == null) {
      return left(const ValidationFailure(message: 'No active session'));
    }

    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.completeWorkoutSession(
      sessionId: currentSession.id,
      notes: notes,
    );

    result.fold(
      (failure) => null,
      (completedSession) {
        // Clear active session, rest timer, and refresh history
        state = const AsyncData(null);
        ref.read(restTimerContextProvider.notifier).stopRest();
        ref.invalidate(clientWorkoutHistoryProvider);
      },
    );

    return result;
  }

  /// Cancel/abandon the workout session
  Future<Either<Failure, Unit>> cancelSession() async {
    final currentSession = state.valueOrNull;
    if (currentSession == null) {
      return right(unit);
    }

    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.deleteWorkoutSession(currentSession.id);

    result.fold(
      (failure) => null,
      (_) {
        state = const AsyncData(null);
        ref.read(restTimerContextProvider.notifier).stopRest();
      },
    );

    return result;
  }

  /// Clear the active session (without deleting)
  void clearSession() {
    state = const AsyncData(null);
    ref.read(restTimerContextProvider.notifier).stopRest();
  }
}
