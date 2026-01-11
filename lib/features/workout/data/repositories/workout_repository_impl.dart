import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/workout_plan.dart';
import '../../domain/repositories/workout_repository.dart';

class SupabaseWorkoutRepository implements WorkoutRepository {
  SupabaseWorkoutRepository(this._client);

  final SupabaseClient _client;

  // ===== Workout Plans =====

  @override
  Future<Either<Failure, List<WorkoutPlan>>> getPlansByTrainer(
      String trainerId) async {
    try {
      final response = await _client
          .from('workout_plans')
          .select()
          .eq('trainer_id', trainerId)
          .order('name', ascending: true);

      final plans = (response as List)
          .map((json) =>
              WorkoutPlan.fromJson(_snakeToCamel(json as Map<String, dynamic>)))
          .toList();

      return right(plans);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load plans: $e'));
    }
  }

  @override
  Future<Either<Failure, WorkoutPlan>> getPlanById(String planId) async {
    try {
      // Get the plan
      final planResponse = await _client
          .from('workout_plans')
          .select()
          .eq('id', planId)
          .single();

      // Get the exercises with their names
      final exercisesResponse = await _client
          .from('plan_exercises')
          .select('*, exercises(name)')
          .eq('plan_id', planId)
          .order('order_index', ascending: true);

      final exercises = (exercisesResponse as List).map((json) {
        final exerciseData = json as Map<String, dynamic>;
        final exerciseName = exerciseData['exercises']?['name'] as String?;

        return PlanExercise.fromJson(_snakeToCamel({
          ...exerciseData,
          'exercise_name': exerciseName,
        }..remove('exercises')));
      }).toList();

      final plan = WorkoutPlan.fromJson(_snakeToCamel(planResponse))
          .copyWith(exercises: exercises);

      return right(plan);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load plan: $e'));
    }
  }

  @override
  Future<Either<Failure, WorkoutPlan>> createPlan(WorkoutPlan plan) async {
    try {
      final response = await _client
          .from('workout_plans')
          .insert({
            'name': plan.name,
            'description': plan.description,
            'trainer_id': plan.trainerId,
          })
          .select()
          .single();

      return right(WorkoutPlan.fromJson(_snakeToCamel(response)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to create plan: $e'));
    }
  }

  @override
  Future<Either<Failure, WorkoutPlan>> updatePlan(WorkoutPlan plan) async {
    try {
      final response = await _client
          .from('workout_plans')
          .update({
            'name': plan.name,
            'description': plan.description,
          })
          .eq('id', plan.id)
          .select()
          .single();

      return right(WorkoutPlan.fromJson(_snakeToCamel(response)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update plan: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deletePlan(String planId) async {
    try {
      // First delete all exercises in the plan
      await _client.from('plan_exercises').delete().eq('plan_id', planId);

      // Then delete the plan
      await _client.from('workout_plans').delete().eq('id', planId);

      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to delete plan: $e'));
    }
  }

  // ===== Plan Exercises =====

  @override
  Future<Either<Failure, PlanExercise>> addExerciseToPlan(
      PlanExercise exercise) async {
    try {
      final response = await _client
          .from('plan_exercises')
          .insert({
            'plan_id': exercise.planId,
            'exercise_id': exercise.exerciseId,
            'sets': exercise.sets,
            'reps': exercise.reps,
            'tempo': exercise.tempo,
            'rest_seconds': exercise.restSeconds,
            'notes': exercise.notes,
            'order_index': exercise.orderIndex,
          })
          .select('*, exercises(name)')
          .single();

      final exerciseName = response['exercises']?['name'] as String?;

      return right(PlanExercise.fromJson(_snakeToCamel({
        ...response,
        'exercise_name': exerciseName,
      }..remove('exercises'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to add exercise: $e'));
    }
  }

  @override
  Future<Either<Failure, PlanExercise>> updatePlanExercise(
      PlanExercise exercise) async {
    try {
      final response = await _client
          .from('plan_exercises')
          .update({
            'sets': exercise.sets,
            'reps': exercise.reps,
            'tempo': exercise.tempo,
            'rest_seconds': exercise.restSeconds,
            'notes': exercise.notes,
            'order_index': exercise.orderIndex,
          })
          .eq('id', exercise.id)
          .select('*, exercises(name)')
          .single();

      final exerciseName = response['exercises']?['name'] as String?;

      return right(PlanExercise.fromJson(_snakeToCamel({
        ...response,
        'exercise_name': exerciseName,
      }..remove('exercises'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update exercise: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeExerciseFromPlan(String exerciseId) async {
    try {
      await _client.from('plan_exercises').delete().eq('id', exerciseId);
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to remove exercise: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> reorderPlanExercises(
    String planId,
    List<String> exerciseIds,
  ) async {
    try {
      // Update each exercise's order index
      for (int i = 0; i < exerciseIds.length; i++) {
        await _client
            .from('plan_exercises')
            .update({'order_index': i})
            .eq('id', exerciseIds[i]);
      }
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to reorder exercises: $e'));
    }
  }

  // ===== Client Plan Assignments =====

  @override
  Future<Either<Failure, ClientPlan>> assignPlanToClient({
    required String planId,
    required String clientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Deactivate any existing active plans for this client
      await _client
          .from('client_plans')
          .update({'is_active': false})
          .eq('client_id', clientId)
          .eq('is_active', true);

      final response = await _client
          .from('client_plans')
          .insert({
            'plan_id': planId,
            'client_id': clientId,
            'start_date': startDate?.toIso8601String(),
            'end_date': endDate?.toIso8601String(),
            'is_active': true,
          })
          .select('*, workout_plans(name)')
          .single();

      final planName = response['workout_plans']?['name'] as String?;

      return right(ClientPlan.fromJson(_snakeToCamel({
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to assign plan: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ClientPlan>>> getClientPlans(
      String clientId) async {
    try {
      final response = await _client
          .from('client_plans')
          .select('*, workout_plans(name)')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      final plans = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        final planName = data['workout_plans']?['name'] as String?;

        return ClientPlan.fromJson(_snakeToCamel({
          ...data,
          'plan_name': planName,
        }..remove('workout_plans')));
      }).toList();

      return right(plans);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load client plans: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ClientPlan>>> getClientsForPlan(
      String planId) async {
    try {
      final response = await _client
          .from('client_plans')
          .select('*, profiles(full_name, email)')
          .eq('plan_id', planId)
          .order('created_at', ascending: false);

      final plans = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        return ClientPlan.fromJson(_snakeToCamel(data..remove('profiles')));
      }).toList();

      return right(plans);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load clients: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deactivateClientPlan(
      String clientPlanId) async {
    try {
      await _client
          .from('client_plans')
          .update({'is_active': false})
          .eq('id', clientPlanId);
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to deactivate plan: $e'));
    }
  }

  @override
  Future<Either<Failure, ClientPlan?>> getActiveClientPlan(
      String clientId) async {
    try {
      final response = await _client
          .from('client_plans')
          .select('*, workout_plans(name)')
          .eq('client_id', clientId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        return right(null);
      }

      final planName = response['workout_plans']?['name'] as String?;

      return right(ClientPlan.fromJson(_snakeToCamel({
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load active plan: $e'));
    }
  }

  /// Convert snake_case keys to camelCase for Dart models
  Map<String, dynamic> _snakeToCamel(Map<String, dynamic> json) {
    return json.map((key, value) {
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      return MapEntry(camelKey, value);
    });
  }
}
