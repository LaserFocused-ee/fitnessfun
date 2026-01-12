import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/workout_plan.dart';
import '../entities/workout_session.dart';

/// Repository interface for workout plan operations
abstract class WorkoutRepository {
  // ===== Workout Plans =====

  /// Get all plans created by a trainer
  Future<Either<Failure, List<WorkoutPlan>>> getPlansByTrainer(String trainerId);

  /// Get a single plan by ID with its exercises
  Future<Either<Failure, WorkoutPlan>> getPlanById(String planId);

  /// Create a new workout plan
  Future<Either<Failure, WorkoutPlan>> createPlan(WorkoutPlan plan);

  /// Update an existing workout plan
  Future<Either<Failure, WorkoutPlan>> updatePlan(WorkoutPlan plan);

  /// Delete a workout plan
  Future<Either<Failure, Unit>> deletePlan(String planId);

  // ===== Plan Exercises =====

  /// Add an exercise to a plan
  Future<Either<Failure, PlanExercise>> addExerciseToPlan(PlanExercise exercise);

  /// Update an exercise in a plan
  Future<Either<Failure, PlanExercise>> updatePlanExercise(PlanExercise exercise);

  /// Remove an exercise from a plan
  Future<Either<Failure, Unit>> removeExerciseFromPlan(String exerciseId);

  /// Reorder exercises in a plan
  Future<Either<Failure, Unit>> reorderPlanExercises(
    String planId,
    List<String> exerciseIds,
  );

  // ===== Client Plan Assignments =====

  /// Assign a plan to a client
  Future<Either<Failure, ClientPlan>> assignPlanToClient({
    required String planId,
    required String clientId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get all plans assigned to a client
  Future<Either<Failure, List<ClientPlan>>> getClientPlans(String clientId);

  /// Get all clients assigned to a specific plan
  Future<Either<Failure, List<ClientPlan>>> getClientsForPlan(String planId);

  /// Deactivate a client plan assignment
  Future<Either<Failure, Unit>> deactivateClientPlan(String clientPlanId);

  /// Get active plan for a client (if any)
  Future<Either<Failure, ClientPlan?>> getActiveClientPlan(String clientId);

  // ===== Workout Sessions =====

  /// Start a new workout session
  Future<Either<Failure, WorkoutSession>> startWorkoutSession({
    required String clientId,
    required String planId,
    String? clientPlanId,
  });

  /// Complete a workout session
  Future<Either<Failure, WorkoutSession>> completeWorkoutSession({
    required String sessionId,
    String? notes,
  });

  /// Get a workout session by ID with exercise logs
  Future<Either<Failure, WorkoutSession>> getWorkoutSession(String sessionId);

  /// Get all workout sessions for a client
  Future<Either<Failure, List<WorkoutSession>>> getClientWorkoutSessions(
    String clientId, {
    int limit = 50,
  });

  /// Get workout sessions for a specific plan by client
  Future<Either<Failure, List<WorkoutSession>>> getSessionsByPlan(
    String clientId,
    String planId,
  );

  /// Delete a workout session
  Future<Either<Failure, Unit>> deleteWorkoutSession(String sessionId);

  // ===== Exercise Logs =====

  /// Save/update an exercise log within a session
  Future<Either<Failure, ExerciseLog>> saveExerciseLog(ExerciseLog log);

  /// Get all exercise logs for a session
  Future<Either<Failure, List<ExerciseLog>>> getExerciseLogs(String sessionId);

  /// Update exercise log (mark complete, add notes, etc.)
  Future<Either<Failure, ExerciseLog>> updateExerciseLog(ExerciseLog log);
}
