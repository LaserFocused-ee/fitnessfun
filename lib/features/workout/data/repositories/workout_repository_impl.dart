import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/plan_exercise_set.dart';
import '../../domain/entities/workout_plan.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/repositories/workout_repository.dart';
import 'client_plan_repository_mixin.dart';
import 'exercise_log_repository_mixin.dart';
import 'plan_exercise_repository_mixin.dart';
import 'workout_plan_repository_mixin.dart';
import 'workout_session_repository_mixin.dart';

/// Supabase implementation of [WorkoutRepository].
///
/// This class uses mixins to organize related functionality:
/// - [WorkoutPlanRepositoryMixin]: Plan CRUD operations
/// - [PlanExerciseRepositoryMixin]: Plan exercise operations
/// - [ClientPlanRepositoryMixin]: Client plan assignment operations
/// - [WorkoutSessionRepositoryMixin]: Workout session operations
/// - [ExerciseLogRepositoryMixin]: Exercise log operations
class SupabaseWorkoutRepository
    with
        WorkoutPlanRepositoryMixin,
        PlanExerciseRepositoryMixin,
        ClientPlanRepositoryMixin,
        WorkoutSessionRepositoryMixin,
        ExerciseLogRepositoryMixin
    implements WorkoutRepository {
  SupabaseWorkoutRepository(this._client);

  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;
}
