import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/workout_session.dart';
import 'supabase_utils.dart';

/// Mixin providing workout session operations
mixin WorkoutSessionRepositoryMixin {
  SupabaseClient get client;

  Future<Either<Failure, WorkoutSession>> startWorkoutSession({
    required String clientId,
    required String planId,
    String? clientPlanId,
  }) async {
    try {
      // Always use UTC to ensure consistent timezone handling
      final now = DateTime.now().toUtc().toIso8601String();

      final response = await client
          .from('workout_sessions')
          .insert({
            'client_id': clientId,
            'plan_id': planId,
            'client_plan_id': clientPlanId,
            'started_at': now,
          })
          .select('*, workout_plans(name)')
          .single();

      final planName = response['workout_plans']?['name'] as String?;

      // Get the plan exercises with their sets and exercise details
      final planExercises = await client
          .from('plan_exercises')
          .select('*, exercises(name, tempo), plan_exercise_sets(*)')
          .eq('plan_id', planId)
          .order('order_index', ascending: true);

      final sessionJson = snakeToCamel(<String, dynamic>{
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'));

      // Ensure startedAt is set (workaround for any parsing issues)
      final session = WorkoutSession.fromJson(sessionJson as Map<String, dynamic>).copyWith(
        startedAt: sessionJson['startedAt'] != null
            ? DateTime.tryParse(sessionJson['startedAt'].toString())
            : DateTime.now().toUtc(),
      );

      // Create exercise logs for each plan exercise with set data from plan_exercise_sets
      final exerciseLogs = <ExerciseLog>[];
      for (final pe in planExercises as List) {
        final exerciseData = pe as Map<String, dynamic>;
        final exerciseInfo = exerciseData['exercises'] as Map<String, dynamic>?;
        final exerciseName = exerciseInfo?['name'] as String?;
        final exerciseTempoDefault = exerciseInfo?['tempo'] as String?;
        final exerciseNotesDefault = exerciseData['notes'] as String?;

        // Get the sets for this exercise
        final planSets = (exerciseData['plan_exercise_sets'] as List? ?? [])
          ..sort((a, b) => (a['set_number'] as int).compareTo(b['set_number'] as int));

        // Initialize set data with target values from plan_exercise_sets
        final setData = planSets.isEmpty
            ? [{'setNumber': 1, 'targetReps': 10, 'reps': null, 'weight': null, 'completed': false}]
            : planSets.map((ps) => {
                'setNumber': ps['set_number'],
                'targetReps': ps['reps'],
                'targetRepsMax': ps['reps_max'],
                'targetWeight': ps['weight'],
                'reps': null,
                'weight': null,
                'completed': false,
              }).toList();

        final logResponse = await client
            .from('exercise_logs')
            .insert({
              'session_id': session.id,
              'plan_exercise_id': exerciseData['id'],
              'completed': false,
              'set_data': setData,
            })
            .select()
            .single();

        // Use exercise default tempo (prefer over plan_exercises.tempo for backward compatibility)
        final targetTempo = exerciseTempoDefault ?? exerciseData['tempo'] as String?;

        exerciseLogs.add(ExerciseLog.fromJson(snakeToCamel(<String, dynamic>{
          ...logResponse,
          'exercise_name': exerciseName,
          'exercise_notes': exerciseNotesDefault,
          'target_rest_min': exerciseData['rest_min'],
          'target_rest_max': exerciseData['rest_max'],
          'target_tempo': targetTempo,
        })));
      }

      return right(session.copyWith(exerciseLogs: exerciseLogs));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to start session: $e'));
    }
  }

  Future<Either<Failure, WorkoutSession>> completeWorkoutSession({
    required String sessionId,
    String? notes,
  }) async {
    try {
      final response = await client
          .from('workout_sessions')
          .update({
            'completed_at': DateTime.now().toUtc().toIso8601String(),
            'notes': notes,
          })
          .eq('id', sessionId)
          .select('*, workout_plans(name)')
          .single();

      final planName = response['workout_plans']?['name'] as String?;

      return right(WorkoutSession.fromJson(snakeToCamel(<String, dynamic>{
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to complete session: $e'));
    }
  }

  Future<Either<Failure, WorkoutSession>> getWorkoutSession(
      String sessionId) async {
    try {
      final response = await client
          .from('workout_sessions')
          .select('*, workout_plans(name)')
          .eq('id', sessionId)
          .single();

      final planName = response['workout_plans']?['name'] as String?;

      // Get exercise logs with plan exercise details and exercise defaults
      final logsResponse = await client
          .from('exercise_logs')
          .select('*, plan_exercises(tempo, rest_min, rest_max, notes, exercises(name, tempo))')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final logs = (logsResponse as List).map((log) {
        final logData = log as Map<String, dynamic>;
        final planExercise = logData['plan_exercises'] as Map<String, dynamic>?;
        final exerciseInfo = planExercise?['exercises'] as Map<String, dynamic>?;
        final exerciseName = exerciseInfo?['name'] as String?;
        final exerciseTempoDefault = exerciseInfo?['tempo'] as String?;
        final exerciseNotesDefault = planExercise?['notes'] as String?;
        // Prefer exercise tempo over plan_exercise tempo
        final targetTempo = exerciseTempoDefault ?? planExercise?['tempo'] as String?;

        return ExerciseLog.fromJson(snakeToCamel(<String, dynamic>{
          ...logData,
          'exercise_name': exerciseName,
          'exercise_notes': exerciseNotesDefault,
          'target_rest_min': planExercise?['rest_min'],
          'target_rest_max': planExercise?['rest_max'],
          'target_tempo': targetTempo,
        }..remove('plan_exercises')));
      }).toList();

      final sessionJson = snakeToCamel(<String, dynamic>{
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'));

      // Ensure startedAt is set (workaround for any parsing issues)
      final session = WorkoutSession.fromJson(sessionJson as Map<String, dynamic>).copyWith(
        exerciseLogs: logs,
        startedAt: sessionJson['startedAt'] != null
            ? DateTime.tryParse(sessionJson['startedAt'].toString())
            : null,
      );

      return right(session);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load session: $e'));
    }
  }

  Future<Either<Failure, List<WorkoutSession>>> getClientWorkoutSessions(
    String clientId, {
    int limit = 50,
  }) async {
    try {
      final response = await client
          .from('workout_sessions')
          .select('''
            *,
            workout_plans(name),
            exercise_logs(
              *,
              plan_exercises(tempo, rest_min, rest_max, notes, exercises(name, tempo))
            )
          ''')
          .eq('client_id', clientId)
          .not('completed_at', 'is', null) // Only completed sessions
          .order('started_at', ascending: false)
          .limit(limit);

      final sessions = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        final planName = data['workout_plans']?['name'] as String?;

        // Parse exercise logs
        final exerciseLogsJson = data['exercise_logs'] as List? ?? [];
        final exerciseLogs = exerciseLogsJson.map((logData) {
          final log = logData as Map<String, dynamic>;
          final planExercise = log['plan_exercises'] as Map<String, dynamic>?;
          final exerciseInfo = planExercise?['exercises'] as Map<String, dynamic>?;
          final exerciseName = exerciseInfo?['name'] as String?;
          final exerciseTempoDefault = exerciseInfo?['tempo'] as String?;
          final exerciseNotesDefault = planExercise?['notes'] as String?;
          // Prefer exercise tempo over plan_exercise tempo
          final targetTempo = exerciseTempoDefault ?? planExercise?['tempo'] as String?;

          return snakeToCamel(<String, dynamic>{
            ...log,
            'exercise_name': exerciseName,
            'exercise_notes': exerciseNotesDefault,
            'target_tempo': targetTempo,
            'target_rest_min': planExercise?['rest_min'],
            'target_rest_max': planExercise?['rest_max'],
          }..remove('plan_exercises'));
        }).toList();

        return WorkoutSession.fromJson(snakeToCamel(<String, dynamic>{
          ...data,
          'plan_name': planName,
          'exercise_logs': exerciseLogs,
        }..remove('workout_plans')));
      }).toList();

      return right(sessions);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load sessions: $e'));
    }
  }

  Future<Either<Failure, List<WorkoutSession>>> getSessionsByPlan(
    String clientId,
    String planId,
  ) async {
    try {
      final response = await client
          .from('workout_sessions')
          .select('*, workout_plans(name)')
          .eq('client_id', clientId)
          .eq('plan_id', planId)
          .order('started_at', ascending: false);

      final sessions = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        final planName = data['workout_plans']?['name'] as String?;

        return WorkoutSession.fromJson(snakeToCamel(<String, dynamic>{
          ...data,
          'plan_name': planName,
        }..remove('workout_plans')));
      }).toList();

      return right(sessions);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load sessions: $e'));
    }
  }

  Future<Either<Failure, Unit>> deleteWorkoutSession(String sessionId) async {
    try {
      // Exercise logs cascade delete
      await client.from('workout_sessions').delete().eq('id', sessionId);
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to delete session: $e'));
    }
  }

  Future<Either<Failure, WorkoutSession?>> getActiveSession(
      String clientId) async {
    try {
      // Find session where started_at is set but completed_at is null
      final response = await client
          .from('workout_sessions')
          .select('*, workout_plans(name)')
          .eq('client_id', clientId)
          .not('started_at', 'is', null)
          .isFilter('completed_at', null)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return right(null);
      }

      final planName = response['workout_plans']?['name'] as String?;

      // Get exercise logs with plan exercise details and exercise defaults
      final logsResponse = await client
          .from('exercise_logs')
          .select(
              '*, plan_exercises(tempo, rest_min, rest_max, notes, exercises(name, tempo))')
          .eq('session_id', response['id'])
          .order('created_at', ascending: true);

      final logs = (logsResponse as List).map((log) {
        final logData = log as Map<String, dynamic>;
        final planExercise = logData['plan_exercises'] as Map<String, dynamic>?;
        final exerciseInfo = planExercise?['exercises'] as Map<String, dynamic>?;
        final exerciseName = exerciseInfo?['name'] as String?;
        final exerciseTempoDefault = exerciseInfo?['tempo'] as String?;
        final exerciseNotesDefault = planExercise?['notes'] as String?;
        // Prefer exercise tempo over plan_exercise tempo
        final targetTempo = exerciseTempoDefault ?? planExercise?['tempo'] as String?;

        return ExerciseLog.fromJson(snakeToCamel(<String, dynamic>{
          ...logData,
          'exercise_name': exerciseName,
          'exercise_notes': exerciseNotesDefault,
          'target_rest_min': planExercise?['rest_min'],
          'target_rest_max': planExercise?['rest_max'],
          'target_tempo': targetTempo,
        }..remove('plan_exercises')));
      }).toList();

      final sessionJson = snakeToCamel(<String, dynamic>{
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'));

      final session = WorkoutSession.fromJson(sessionJson as Map<String, dynamic>).copyWith(
        exerciseLogs: logs,
        startedAt: sessionJson['startedAt'] != null
            ? DateTime.tryParse(sessionJson['startedAt'].toString())
            : null,
      );

      return right(session);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to get active session: $e'));
    }
  }
}
