import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

@freezed
class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required String name,
    String? instructions,
    String? videoUrl,
    String? muscleGroup,
    String? createdBy,
    @Default(false) bool isGlobal,
    DateTime? createdAt,
  }) = _Exercise;

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);

  /// Empty factory for form initialization
  factory Exercise.empty() => const Exercise(
        id: '',
        name: '',
      );
}

/// Muscle groups for categorization
class MuscleGroups {
  static const String chest = 'Chest';
  static const String back = 'Back';
  static const String shoulders = 'Shoulders';
  static const String biceps = 'Biceps';
  static const String triceps = 'Triceps';
  static const String forearms = 'Forearms';
  static const String core = 'Core';
  static const String quadriceps = 'Quadriceps';
  static const String hamstrings = 'Hamstrings';
  static const String glutes = 'Glutes';
  static const String calves = 'Calves';
  static const String fullBody = 'Full Body';
  static const String cardio = 'Cardio';

  static const List<String> all = [
    chest,
    back,
    shoulders,
    biceps,
    triceps,
    forearms,
    core,
    quadriceps,
    hamstrings,
    glutes,
    calves,
    fullBody,
    cardio,
  ];
}
