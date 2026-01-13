import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_exercise_set.freezed.dart';
part 'plan_exercise_set.g.dart';

/// Represents a single set configuration within a plan exercise.
/// Supports per-set customization (pyramid sets, drop sets, etc.)
@freezed
class PlanExerciseSet with _$PlanExerciseSet {
  const factory PlanExerciseSet({
    required String id,
    required String planExerciseId,
    required int setNumber,
    required int reps,
    int? repsMax,      // For rep ranges like 8-10
    double? weight,    // Target weight in kg (nullable)
    DateTime? createdAt,
  }) = _PlanExerciseSet;

  factory PlanExerciseSet.fromJson(Map<String, dynamic> json) =>
      _$PlanExerciseSetFromJson(json);

  /// Create an empty set for a new entry in the UI
  factory PlanExerciseSet.empty({
    required String planExerciseId,
    required int setNumber,
    int reps = 10,
    int? repsMax,
    double? weight,
  }) =>
      PlanExerciseSet(
        id: '',
        planExerciseId: planExerciseId,
        setNumber: setNumber,
        reps: reps,
        repsMax: repsMax,
        weight: weight,
      );
}
