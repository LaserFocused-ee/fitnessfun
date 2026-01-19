import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/plan_exercise_set.dart';
import '../../domain/entities/workout_plan.dart';
import 'supabase_utils.dart';

/// Mixin providing workout plan CRUD operations
mixin WorkoutPlanRepositoryMixin {
  SupabaseClient get client;

  Future<Either<Failure, List<WorkoutPlan>>> getPlansByTrainer(
      String trainerId) async {
    try {
      final response = await client
          .from('workout_plans')
          .select()
          .eq('trainer_id', trainerId)
          .order('name', ascending: true);

      final plans = (response as List)
          .map((json) =>
              WorkoutPlan.fromJson(snakeToCamel(json)))
          .toList();

      return right(plans);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load plans: $e'));
    }
  }

  Future<Either<Failure, WorkoutPlan>> getPlanById(String planId) async {
    try {
      // Get the plan
      final planResponse = await client
          .from('workout_plans')
          .select()
          .eq('id', planId)
          .single();

      // Get the exercises with their names, video paths, and sets
      final exercisesResponse = await client
          .from('plan_exercises')
          .select('*, exercises(name, video_path), plan_exercise_sets(*)')
          .eq('plan_id', planId)
          .order('order_index', ascending: true);

      final exercises = (exercisesResponse as List).map((json) {
        final exerciseData = json as Map<String, dynamic>;
        final exerciseInfo = exerciseData['exercises'] as Map<String, dynamic>?;
        final exerciseName = exerciseInfo?['name'] as String?;
        final videoPath = exerciseInfo?['video_path'] as String?;

        // Generate full video URL if path exists
        String? videoUrl;
        if (videoPath != null && videoPath.isNotEmpty) {
          videoUrl = client.storage
              .from('exercise-videos')
              .getPublicUrl(videoPath);
        }

        // Parse the sets
        final setsData = exerciseData['plan_exercise_sets'] as List? ?? [];
        final sets = setsData
            .map((s) => PlanExerciseSet.fromJson(snakeToCamel(s)))
            .toList()
          ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

        return PlanExercise.fromJson(snakeToCamel(<String, dynamic>{
          ...exerciseData,
          'exercise_name': exerciseName,
          'exercise_video_url': videoUrl,
        }..remove('exercises')..remove('plan_exercise_sets'))).copyWith(sets: sets);
      }).toList();

      final plan = WorkoutPlan.fromJson(snakeToCamel(planResponse as Map<String, dynamic>))
          .copyWith(exercises: exercises);

      return right(plan);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load plan: $e'));
    }
  }

  Future<Either<Failure, WorkoutPlan>> createPlan(WorkoutPlan plan) async {
    try {
      final response = await client
          .from('workout_plans')
          .insert({
            'name': plan.name,
            'description': plan.description,
            'trainer_id': plan.trainerId,
          })
          .select()
          .single();

      return right(WorkoutPlan.fromJson(snakeToCamel(response as Map<String, dynamic>)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to create plan: $e'));
    }
  }

  Future<Either<Failure, WorkoutPlan>> updatePlan(WorkoutPlan plan) async {
    try {
      final response = await client
          .from('workout_plans')
          .update({
            'name': plan.name,
            'description': plan.description,
          })
          .eq('id', plan.id)
          .select()
          .single();

      return right(WorkoutPlan.fromJson(snakeToCamel(response as Map<String, dynamic>)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update plan: $e'));
    }
  }

  Future<Either<Failure, Unit>> deletePlan(String planId) async {
    try {
      // First delete all exercises in the plan
      await client.from('plan_exercises').delete().eq('plan_id', planId);

      // Then delete the plan
      await client.from('workout_plans').delete().eq('id', planId);

      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to delete plan: $e'));
    }
  }
}
