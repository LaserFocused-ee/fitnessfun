import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/workout_plan.dart';
import 'supabase_utils.dart';

/// Mixin providing client plan assignment operations
mixin ClientPlanRepositoryMixin {
  SupabaseClient get client;

  Future<Either<Failure, ClientPlan>> assignPlanToClient({
    required String planId,
    required String clientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Deactivate any existing active plans for this client
      await client
          .from('client_plans')
          .update({'is_active': false})
          .eq('client_id', clientId)
          .eq('is_active', true);

      final response = await client
          .from('client_plans')
          .insert({
            'plan_id': planId,
            'client_id': clientId,
            'start_date': startDate?.toIso8601String(),
            'end_date': endDate?.toIso8601String(),
            'is_active': true,
          })
          .select('*, workout_plans(name, trainer_id)')
          .single();

      final workoutPlan = response['workout_plans'] as Map<String, dynamic>?;
      final planName = workoutPlan?['name'] as String?;
      final trainerId = workoutPlan?['trainer_id'] as String?;

      return right(ClientPlan.fromJson(snakeToCamel(<String, dynamic>{
        ...response,
        'plan_name': planName,
        'trainer_id': trainerId,
      }..remove('workout_plans'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to assign plan: $e'));
    }
  }

  Future<Either<Failure, List<ClientPlan>>> getClientPlans(
      String clientId) async {
    try {
      final response = await client
          .from('client_plans')
          .select('*, workout_plans(name, trainer_id)')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      final plans = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        final workoutPlan = data['workout_plans'] as Map<String, dynamic>?;
        final planName = workoutPlan?['name'] as String?;
        final trainerId = workoutPlan?['trainer_id'] as String?;

        return ClientPlan.fromJson(snakeToCamel(<String, dynamic>{
          ...data,
          'plan_name': planName,
          'trainer_id': trainerId,
        }..remove('workout_plans')));
      }).toList();

      return right(plans);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load client plans: $e'));
    }
  }

  Future<Either<Failure, List<ClientPlan>>> getClientsForPlan(
      String planId) async {
    try {
      final response = await client
          .from('client_plans')
          .select('*, profiles(full_name, email)')
          .eq('plan_id', planId)
          .order('created_at', ascending: false);

      final plans = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        return ClientPlan.fromJson(snakeToCamel(<String, dynamic>{...data}..remove('profiles')));
      }).toList();

      return right(plans);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load clients: $e'));
    }
  }

  Future<Either<Failure, Unit>> deactivateClientPlan(
      String clientPlanId) async {
    try {
      await client
          .from('client_plans')
          .update({'is_active': false})
          .eq('id', clientPlanId);
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to deactivate plan: $e'));
    }
  }

  Future<Either<Failure, ClientPlan?>> getActiveClientPlan(
      String clientId) async {
    try {
      final response = await client
          .from('client_plans')
          .select('*, workout_plans(name, trainer_id)')
          .eq('client_id', clientId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        return right(null);
      }

      final workoutPlan = response['workout_plans'] as Map<String, dynamic>?;
      final planName = workoutPlan?['name'] as String?;
      final trainerId = workoutPlan?['trainer_id'] as String?;

      return right(ClientPlan.fromJson(snakeToCamel(<String, dynamic>{
        ...response,
        'plan_name': planName,
        'trainer_id': trainerId,
      }..remove('workout_plans'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load active plan: $e'));
    }
  }
}
