import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_session.freezed.dart';
part 'workout_session.g.dart';

/// A completed or in-progress workout session
@freezed
class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    required String id,
    required String clientId,
    required String planId,
    String? clientPlanId,
    String? planName,
    DateTime? startedAt,
    DateTime? completedAt,
    String? notes,
    @Default([]) List<ExerciseLog> exerciseLogs,
  }) = _WorkoutSession;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSessionFromJson(json);

  factory WorkoutSession.start({
    required String clientId,
    required String planId,
    String? clientPlanId,
    String? planName,
  }) =>
      WorkoutSession(
        id: '',
        clientId: clientId,
        planId: planId,
        clientPlanId: clientPlanId,
        planName: planName,
        startedAt: DateTime.now(),
      );
}

/// Log of a single exercise within a workout session
@freezed
class ExerciseLog with _$ExerciseLog {
  const factory ExerciseLog({
    required String id,
    required String sessionId,
    required String planExerciseId,
    String? exerciseName,
    int? targetSets,
    String? targetReps,
    String? targetTempo,
    String? targetRest,
    @Default(false) bool completed,
    @Default([]) List<SetLog> setData,
    String? notes,
    DateTime? createdAt,
  }) = _ExerciseLog;

  factory ExerciseLog.fromJson(Map<String, dynamic> json) =>
      _$ExerciseLogFromJson(json);

  factory ExerciseLog.fromPlanExercise({
    required String sessionId,
    required String planExerciseId,
    String? exerciseName,
    int? targetSets,
    String? targetReps,
    String? targetTempo,
    String? targetRest,
  }) {
    // Initialize empty set logs based on target sets
    final numSets = targetSets ?? 3;
    final setData = List.generate(
      numSets,
      (i) => SetLog(setNumber: i + 1),
    );

    return ExerciseLog(
      id: '',
      sessionId: sessionId,
      planExerciseId: planExerciseId,
      exerciseName: exerciseName,
      targetSets: targetSets,
      targetReps: targetReps,
      targetTempo: targetTempo,
      targetRest: targetRest,
      setData: setData,
    );
  }
}

/// Log for a single set within an exercise
@freezed
class SetLog with _$SetLog {
  const factory SetLog({
    required int setNumber,
    String? reps,
    String? weight,
    @Default(false) bool completed,
  }) = _SetLog;

  factory SetLog.fromJson(Map<String, dynamic> json) => _$SetLogFromJson(json);
}
