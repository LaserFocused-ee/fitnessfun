import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/plan_exercise_set.dart';
import '../../domain/entities/workout_plan.dart';
import '../../domain/entities/workout_session.dart';
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

      // Get the exercises with their names, video paths, and sets
      final exercisesResponse = await _client
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
          videoUrl = _client.storage
              .from('exercise-videos')
              .getPublicUrl(videoPath);
        }

        // Parse the sets
        final setsData = exerciseData['plan_exercise_sets'] as List? ?? [];
        final sets = setsData
            .map((s) => PlanExerciseSet.fromJson(_snakeToCamel(s as Map<String, dynamic>)))
            .toList()
          ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

        return PlanExercise.fromJson(_snakeToCamel({
          ...exerciseData,
          'exercise_name': exerciseName,
          'exercise_video_url': videoUrl,
        }..remove('exercises')..remove('plan_exercise_sets'))).copyWith(sets: sets);
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
      // Insert the plan_exercise
      final response = await _client
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
        final setResponse = await _client
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
        insertedSets.add(PlanExerciseSet.fromJson(_snakeToCamel(setResponse)));
      }

      return right(PlanExercise.fromJson(_snakeToCamel({
        ...response,
        'exercise_name': exerciseName,
      }..remove('exercises'))).copyWith(sets: insertedSets));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to add exercise: $e'));
    }
  }

  @override
  Future<Either<Failure, PlanExercise>> updatePlanExercise(
      PlanExercise exercise) async {
    try {
      // Update the plan_exercise
      final response = await _client
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
      await _client
          .from('plan_exercise_sets')
          .delete()
          .eq('plan_exercise_id', exercise.id);

      final insertedSets = <PlanExerciseSet>[];
      for (final set in exercise.sets) {
        final setResponse = await _client
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
        insertedSets.add(PlanExerciseSet.fromJson(_snakeToCamel(setResponse)));
      }

      return right(PlanExercise.fromJson(_snakeToCamel({
        ...response,
        'exercise_name': exerciseName,
      }..remove('exercises'))).copyWith(sets: insertedSets));
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

  // ===== Workout Sessions =====

  @override
  Future<Either<Failure, WorkoutSession>> startWorkoutSession({
    required String clientId,
    required String planId,
    String? clientPlanId,
  }) async {
    try {
      // Always use UTC to ensure consistent timezone handling
      final now = DateTime.now().toUtc().toIso8601String();

      final response = await _client
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

      // Get the plan exercises with their sets
      final planExercises = await _client
          .from('plan_exercises')
          .select('*, exercises(name), plan_exercise_sets(*)')
          .eq('plan_id', planId)
          .order('order_index', ascending: true);

      final sessionJson = _snakeToCamel({
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'));

      // Ensure startedAt is set (workaround for any parsing issues)
      final session = WorkoutSession.fromJson(sessionJson).copyWith(
        startedAt: sessionJson['startedAt'] != null
            ? DateTime.tryParse(sessionJson['startedAt'].toString())
            : DateTime.now().toUtc(),
      );

      // Create exercise logs for each plan exercise with set data from plan_exercise_sets
      final exerciseLogs = <ExerciseLog>[];
      for (final pe in planExercises as List) {
        final exerciseData = pe as Map<String, dynamic>;
        final exerciseName = exerciseData['exercises']?['name'] as String?;

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

        final logResponse = await _client
            .from('exercise_logs')
            .insert({
              'session_id': session.id,
              'plan_exercise_id': exerciseData['id'],
              'completed': false,
              'set_data': setData,
            })
            .select()
            .single();

        exerciseLogs.add(ExerciseLog.fromJson(_snakeToCamel({
          ...logResponse,
          'exercise_name': exerciseName,
          'target_rest_min': exerciseData['rest_min'],
          'target_rest_max': exerciseData['rest_max'],
          'target_tempo': exerciseData['tempo'],
        })));
      }

      return right(session.copyWith(exerciseLogs: exerciseLogs));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to start session: $e'));
    }
  }

  @override
  Future<Either<Failure, WorkoutSession>> completeWorkoutSession({
    required String sessionId,
    String? notes,
  }) async {
    try {
      final response = await _client
          .from('workout_sessions')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
            'notes': notes,
          })
          .eq('id', sessionId)
          .select('*, workout_plans(name)')
          .single();

      final planName = response['workout_plans']?['name'] as String?;

      return right(WorkoutSession.fromJson(_snakeToCamel({
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to complete session: $e'));
    }
  }

  @override
  Future<Either<Failure, WorkoutSession>> getWorkoutSession(
      String sessionId) async {
    try {
      final response = await _client
          .from('workout_sessions')
          .select('*, workout_plans(name)')
          .eq('id', sessionId)
          .single();

      final planName = response['workout_plans']?['name'] as String?;

      // Get exercise logs with plan exercise details
      final logsResponse = await _client
          .from('exercise_logs')
          .select('*, plan_exercises(tempo, rest_min, rest_max, exercises(name))')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final logs = (logsResponse as List).map((log) {
        final logData = log as Map<String, dynamic>;
        final planExercise = logData['plan_exercises'] as Map<String, dynamic>?;
        final exerciseName = planExercise?['exercises']?['name'] as String?;

        return ExerciseLog.fromJson(_snakeToCamel({
          ...logData,
          'exercise_name': exerciseName,
          'target_rest_min': planExercise?['rest_min'],
          'target_rest_max': planExercise?['rest_max'],
          'target_tempo': planExercise?['tempo'],
        }..remove('plan_exercises')));
      }).toList();

      final sessionJson = _snakeToCamel({
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'));

      // Ensure startedAt is set (workaround for any parsing issues)
      final session = WorkoutSession.fromJson(sessionJson).copyWith(
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

  @override
  Future<Either<Failure, List<WorkoutSession>>> getClientWorkoutSessions(
    String clientId, {
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from('workout_sessions')
          .select('''
            *,
            workout_plans(name),
            exercise_logs(
              *,
              plan_exercises(tempo, rest_min, rest_max, exercises(name))
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
          final exerciseName = planExercise?['exercises']?['name'] as String?;

          return _snakeToCamel({
            ...log,
            'exercise_name': exerciseName,
            'target_tempo': planExercise?['tempo'],
            'target_rest_min': planExercise?['rest_min'],
            'target_rest_max': planExercise?['rest_max'],
          }..remove('plan_exercises'));
        }).toList();

        return WorkoutSession.fromJson(_snakeToCamel({
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

  @override
  Future<Either<Failure, List<WorkoutSession>>> getSessionsByPlan(
    String clientId,
    String planId,
  ) async {
    try {
      final response = await _client
          .from('workout_sessions')
          .select('*, workout_plans(name)')
          .eq('client_id', clientId)
          .eq('plan_id', planId)
          .order('started_at', ascending: false);

      final sessions = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        final planName = data['workout_plans']?['name'] as String?;

        return WorkoutSession.fromJson(_snakeToCamel({
          ...data,
          'plan_name': planName,
        }..remove('workout_plans')));
      }).toList();

      return right(sessions);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load sessions: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteWorkoutSession(String sessionId) async {
    try {
      // Exercise logs cascade delete
      await _client.from('workout_sessions').delete().eq('id', sessionId);
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to delete session: $e'));
    }
  }

  @override
  Future<Either<Failure, WorkoutSession?>> getActiveSession(
      String clientId) async {
    try {
      // Find session where started_at is set but completed_at is null
      final response = await _client
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

      // Get exercise logs with plan exercise details
      final logsResponse = await _client
          .from('exercise_logs')
          .select(
              '*, plan_exercises(tempo, rest_min, rest_max, exercises(name))')
          .eq('session_id', response['id'])
          .order('created_at', ascending: true);

      final logs = (logsResponse as List).map((log) {
        final logData = log as Map<String, dynamic>;
        final planExercise = logData['plan_exercises'] as Map<String, dynamic>?;
        final exerciseName = planExercise?['exercises']?['name'] as String?;

        return ExerciseLog.fromJson(_snakeToCamel({
          ...logData,
          'exercise_name': exerciseName,
          'target_rest_min': planExercise?['rest_min'],
          'target_rest_max': planExercise?['rest_max'],
          'target_tempo': planExercise?['tempo'],
        }..remove('plan_exercises')));
      }).toList();

      final sessionJson = _snakeToCamel({
        ...response,
        'plan_name': planName,
      }..remove('workout_plans'));

      final session = WorkoutSession.fromJson(sessionJson).copyWith(
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

  // ===== Exercise Logs =====

  @override
  Future<Either<Failure, ExerciseLog>> saveExerciseLog(ExerciseLog log) async {
    try {
      final setDataJson = log.setData.map((s) => s.toJson()).toList();

      final response = await _client
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

      return right(ExerciseLog.fromJson(_snakeToCamel(response)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to save exercise log: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ExerciseLog>>> getExerciseLogs(
      String sessionId) async {
    try {
      final response = await _client
          .from('exercise_logs')
          .select('*, plan_exercises(tempo, rest_min, rest_max, exercises(name))')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final logs = (response as List).map((log) {
        final logData = log as Map<String, dynamic>;
        final planExercise = logData['plan_exercises'] as Map<String, dynamic>?;
        final exerciseName = planExercise?['exercises']?['name'] as String?;

        return ExerciseLog.fromJson(_snakeToCamel({
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

  @override
  Future<Either<Failure, ExerciseLog>> updateExerciseLog(
      ExerciseLog log) async {
    try {
      final setDataJson = log.setData.map((s) => s.toJson()).toList();

      final response = await _client
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

  /// Recursively convert snake_case keys to camelCase for Dart models
  dynamic _snakeToCamel(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, v) {
        final camelKey = key.replaceAllMapped(
          RegExp(r'_([a-z])'),
          (match) => match.group(1)!.toUpperCase(),
        );
        return MapEntry(camelKey, _snakeToCamel(v));
      });
    } else if (value is List) {
      return value.map(_snakeToCamel).toList();
    }
    return value;
  }
}
