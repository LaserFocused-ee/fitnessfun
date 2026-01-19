import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/workout_session.dart';
import 'supabase_utils.dart';

/// Mixin providing exercise log operations
mixin ExerciseLogRepositoryMixin {
  SupabaseClient get client;

  Future<Either<Failure, ExerciseLog>> saveExerciseLog(ExerciseLog log) async {
    try {
      final setDataJson = log.setData.map((s) => s.toJson()).toList();

      final response = await client
          .from('exercise_logs')
          .insert({
            'session_id': log.sessionId,
            'plan_exercise_id': log.planExerciseId,
            'completed': log.completed,
            'set_data': setDataJson,
            'notes': log.notes,
          })
          .select()
          .single();

      return right(ExerciseLog.fromJson(snakeToCamel(response as Map<String, dynamic>)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to save exercise log: $e'));
    }
  }

  Future<Either<Failure, List<ExerciseLog>>> getExerciseLogs(
      String sessionId) async {
    try {
      final response = await client
          .from('exercise_logs')
          .select('*, plan_exercises(tempo, rest_min, rest_max, exercises(name))')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final logs = (response as List).map((log) {
        final logData = log as Map<String, dynamic>;
        final planExercise = logData['plan_exercises'] as Map<String, dynamic>?;
        final exerciseName = planExercise?['exercises']?['name'] as String?;

        return ExerciseLog.fromJson(snakeToCamel(<String, dynamic>{
          ...logData,
          'exercise_name': exerciseName,
          'target_tempo': planExercise?['tempo'],
          'target_rest_min': planExercise?['rest_min'],
          'target_rest_max': planExercise?['rest_max'],
        }..remove('plan_exercises')));
      }).toList();

      return right(logs);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load exercise logs: $e'));
    }
  }

  Future<Either<Failure, ExerciseLog>> updateExerciseLog(
      ExerciseLog log) async {
    try {
      final setDataJson = log.setData.map((s) => s.toJson()).toList();

      final response = await client
          .from('exercise_logs')
          .update({
            'completed': log.completed,
            'set_data': setDataJson,
            'notes': log.notes,
          })
          .eq('id', log.id)
          .select()
          .single();

      return right(log.copyWith(
        id: response['id'] as String,
      ));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update exercise log: $e'));
    }
  }
}
