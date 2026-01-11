import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_plan.freezed.dart';
part 'workout_plan.g.dart';

/// A workout plan template created by a trainer
@freezed
class WorkoutPlan with _$WorkoutPlan {
  const factory WorkoutPlan({
    required String id,
    required String name,
    String? description,
    required String trainerId,
    DateTime? createdAt,
    @Default([]) List<PlanExercise> exercises,
  }) = _WorkoutPlan;

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) =>
      _$WorkoutPlanFromJson(json);

  factory WorkoutPlan.empty({required String trainerId}) => WorkoutPlan(
        id: '',
        name: '',
        trainerId: trainerId,
      );
}

/// An exercise within a workout plan with customizable parameters
@freezed
class PlanExercise with _$PlanExercise {
  const factory PlanExercise({
    required String id,
    required String planId,
    required String exerciseId,
    String? exerciseName, // Denormalized for display
    int? sets,
    String? reps, // "8-10" format for ranges
    String? tempo, // "3111" notation
    String? restSeconds, // "90-120" format for ranges
    String? notes,
    required int orderIndex,
  }) = _PlanExercise;

  factory PlanExercise.fromJson(Map<String, dynamic> json) =>
      _$PlanExerciseFromJson(json);

  factory PlanExercise.empty({
    required String planId,
    required String exerciseId,
    String? exerciseName,
    required int orderIndex,
  }) =>
      PlanExercise(
        id: '',
        planId: planId,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        orderIndex: orderIndex,
      );
}

/// Assignment of a plan to a client
@freezed
class ClientPlan with _$ClientPlan {
  const factory ClientPlan({
    required String id,
    required String clientId,
    required String planId,
    String? planName, // Denormalized for display
    DateTime? startDate,
    DateTime? endDate,
    @Default(true) bool isActive,
    DateTime? createdAt,
  }) = _ClientPlan;

  factory ClientPlan.fromJson(Map<String, dynamic> json) =>
      _$ClientPlanFromJson(json);
}
