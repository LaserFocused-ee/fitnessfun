import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
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

      // Get the exercises with their names and video paths
      final exercisesResponse = await _client
          .from('plan_exercises')
          .select('*, exercises(name, video_path)')
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

        return PlanExercise.fromJson(_snakeToCamel({
          ...exerciseData,
          'exercise_name': exerciseName,
          'exercise_video_url': videoUrl,
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

      // Get the plan exercises to create initial logs
      final planExercises = await _client
          .from('plan_exercises')
          .select('*, exercises(name)')
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

      // Create empty exercise logs for each plan exercise
      final exerciseLogs = <ExerciseLog>[];
      for (final pe in planExercises as List) {
        final exerciseData = pe as Map<String, dynamic>;
        final exerciseName = exerciseData['exercises']?['name'] as String?;
        final targetSets = exerciseData['sets'] as int? ?? 3;

        // Initialize empty set data based on target sets
        final setData = List.generate(
          targetSets,
          (i) => {'setNumber': i + 1, 'reps': null, 'weight': null, 'completed': false},
        );

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
          'target_sets': exerciseData['sets'],
          'target_reps': exerciseData['reps'],
          'target_tempo': exerciseData['tempo'],
          'target_rest': exerciseData['rest_seconds'],
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
          .select('*, plan_exercises(sets, reps, tempo, rest_seconds, exercises(name))')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final logs = (logsResponse as List).map((log) {
        final logData = log as Map<String, dynamic>;
        final planExercise = logData['plan_exercises'] as Map<String, dynamic>?;
        final exerciseName = planExercise?['exercises']?['name'] as String?;

        return ExerciseLog.fromJson(_snakeToCamel({
          ...logData,
          'exercise_name': exerciseName,
          'target_sets': planExercise?['sets'],
          'target_reps': planExercise?['reps'],
          'target_tempo': planExercise?['tempo'],
          'target_rest': planExercise?['rest_seconds'],
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
          .select('*, workout_plans(name)')
          .eq('client_id', clientId)
          .order('started_at', ascending: false)
          .limit(limit);

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
          .select('*, plan_exercises(sets, reps, tempo, rest_seconds, exercises(name))')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final logs = (response as List).map((log) {
        final logData = log as Map<String, dynamic>;
        final planExercise = logData['plan_exercises'] as Map<String, dynamic>?;
        final exerciseName = planExercise?['exercises']?['name'] as String?;

        return ExerciseLog.fromJson(_snakeToCamel({
          ...logData,
          'exercise_name': exerciseName,
          'target_sets': planExercise?['sets'],
          'target_reps': planExercise?['reps'],
          'target_tempo': planExercise?['tempo'],
          'target_rest': planExercise?['rest_seconds'],
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
