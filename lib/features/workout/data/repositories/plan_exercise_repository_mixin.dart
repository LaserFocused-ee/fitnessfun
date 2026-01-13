import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/plan_exercise_set.dart';
import '../../domain/entities/workout_plan.dart';
import 'supabase_utils.dart';

/// Mixin providing plan exercise CRUD operations
mixin PlanExerciseRepositoryMixin {
  SupabaseClient get client;

  Future<Either<Failure, PlanExercise>> addExerciseToPlan(
      PlanExercise exercise) async {
    try {
      // Insert the plan_exercise
      final response = await client
          .from('plan_exercises')
          .insert({
            'plan_id': exercise.planId,
            'exercise_id': exercise.exerciseId,
            'tempo': exercise.tempo,
            'rest_min': exercise.restMin,
            'rest_max': exercise.restMax,
            'notes': exercise.notes,
            'order_index': exercise.orderIndex,
          })
          .select('*, exercises(name)')
          .single();

      final planExerciseId = response['id'] as String;
      final exerciseName = response['exercises']?['name'] as String?;

      // Insert the sets
      final insertedSets = <PlanExerciseSet>[];
      for (final set in exercise.sets) {
        final setResponse = await client
            .from('plan_exercise_sets')
            .insert({
              'plan_exercise_id': planExerciseId,
              'set_number': set.setNumber,
              'reps': set.reps,
              'reps_max': set.repsMax,
              'weight': set.weight,
            })
            .select()
            .single();
        insertedSets.add(PlanExerciseSet.fromJson(snakeToCamel(setResponse)));
      }

      return right(PlanExercise.fromJson(snakeToCamel({
        ...response,
        'exercise_name': exerciseName,
      }..remove('exercises'))).copyWith(sets: insertedSets));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to add exercise: $e'));
    }
  }

  Future<Either<Failure, PlanExercise>> updatePlanExercise(
      PlanExercise exercise) async {
    try {
      // Update the plan_exercise
      final response = await client
          .from('plan_exercises')
          .update({
            'tempo': exercise.tempo,
            'rest_min': exercise.restMin,
            'rest_max': exercise.restMax,
            'notes': exercise.notes,
            'order_index': exercise.orderIndex,
          })
          .eq('id', exercise.id)
          .select('*, exercises(name)')
          .single();

      final exerciseName = response['exercises']?['name'] as String?;

      // Replace the sets: delete old ones, insert new ones
      await client
          .from('plan_exercise_sets')
          .delete()
          .eq('plan_exercise_id', exercise.id);

      final insertedSets = <PlanExerciseSet>[];
      for (final set in exercise.sets) {
        final setResponse = await client
            .from('plan_exercise_sets')
            .insert({
              'plan_exercise_id': exercise.id,
              'set_number': set.setNumber,
              'reps': set.reps,
              'reps_max': set.repsMax,
              'weight': set.weight,
            })
            .select()
            .single();
        insertedSets.add(PlanExerciseSet.fromJson(snakeToCamel(setResponse)));
      }

      return right(PlanExercise.fromJson(snakeToCamel({
        ...response,
        'exercise_name': exerciseName,
      }..remove('exercises'))).copyWith(sets: insertedSets));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update exercise: $e'));
    }
  }

  Future<Either<Failure, Unit>> removeExerciseFromPlan(String exerciseId) async {
    try {
      await client.from('plan_exercises').delete().eq('id', exerciseId);
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to remove exercise: $e'));
    }
  }

  Future<Either<Failure, Unit>> reorderPlanExercises(
    String planId,
    List<String> exerciseIds,
  ) async {
    try {
      // Update each exercise's order index
      for (int i = 0; i < exerciseIds.length; i++) {
        await client
            .from('plan_exercises')
            .update({'order_index': i})
            .eq('id', exerciseIds[i]);
      }
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to reorder exercises: $e'));
    }
  }
}
