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
    String? exerciseNotes, // Default notes from the exercise itself (always shown)
    int? targetRestMin,
    int? targetRestMax,
    String? targetTempo,
    @Default(false) bool completed,
    @Default([]) List<SetLog> setData,
    String? notes, // Client-specific notes for this session
    DateTime? createdAt,
  }) = _ExerciseLog;

  const ExerciseLog._();

  factory ExerciseLog.fromJson(Map<String, dynamic> json) =>
      _$ExerciseLogFromJson(json);

  /// Number of sets is derived from setData length
  int get targetSets => setData.length;

  /// Get target reps display string (e.g., "8-10" or "10")
  String? get targetRepsDisplay {
    if (setData.isEmpty) return null;
    final first = setData.first;
    if (first.targetReps == null) return null;
    if (first.targetRepsMax != null && first.targetRepsMax != first.targetReps) {
      return '${first.targetReps}-${first.targetRepsMax}';
    }
    return '${first.targetReps}';
  }

  /// Get target rest display string (e.g., "90-120s" or "90s")
  String? get targetRestDisplay {
    if (targetRestMin == null) return null;
    if (targetRestMax != null && targetRestMax != targetRestMin) {
      return '$targetRestMin-${targetRestMax}s';
    }
    return '${targetRestMin}s';
  }
}

/// Log for a single set within an exercise
@freezed
class SetLog with _$SetLog {
  const factory SetLog({
    required int setNumber,
    // Target values from plan (for display/comparison)
    int? targetReps,
    int? targetRepsMax,
    double? targetWeight,
    // Actual logged values
    int? reps,
    double? weight,
    String? notes,
    @Default(false) bool completed,
    DateTime? completedAt,
  }) = _SetLog;

  factory SetLog.fromJson(Map<String, dynamic> json) => _$SetLogFromJson(json);
}
