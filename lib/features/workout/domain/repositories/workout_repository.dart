import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/workout_plan.dart';

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
}
