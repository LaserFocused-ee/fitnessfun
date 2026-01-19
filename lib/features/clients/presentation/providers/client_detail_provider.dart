import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/error/failures.dart';
import '../../../checkin/domain/entities/daily_checkin.dart';
import '../../../checkin/domain/utils/checkin_comparison.dart';
import '../../../workout/domain/entities/workout_plan.dart';
import '../../../workout/domain/entities/workout_session.dart';
import '../../../workout/presentation/providers/workout_provider.dart';

part 'client_detail_provider.g.dart';

/// Provides checkins for a specific client (trainer viewing)
@riverpod
Future<List<DailyCheckin>> clientCheckins(
  ClientCheckinsRef ref,
  String clientId,
) async {
  final supabase = ref.watch(supabaseClientProvider);

  try {
    final response = await supabase
        .from('daily_checkins')
        .select()
        .eq('client_id', clientId)
        .order('date', ascending: false)
        .limit(50);

    final checkins = (response as List)
        .map((json) => DailyCheckin.fromJson(_snakeToCamel(json as Map<String, dynamic>)))
        .toList();

    return checkins;
  } catch (e) {
    throw Exception('Failed to load checkins: $e');
  }
}

/// Convert snake_case keys to camelCase for Dart
Map<String, dynamic> _snakeToCamel(Map<String, dynamic> json) {
  return json.map((key, value) {
    final camelKey = key.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
    return MapEntry(camelKey, value);
  });
}

/// Provides checkins with comparison data for a specific client (trainer viewing).
/// Each checkin is paired with its delta compared to the previous checkin.
@riverpod
Future<List<CheckinWithComparison>> clientCheckinsWithComparison(
  ClientCheckinsWithComparisonRef ref,
  String clientId,
) async {
  final checkins = await ref.watch(clientCheckinsProvider(clientId).future);

  // Checkins are sorted by date descending, so index 0 is most recent.
  // We compare each checkin to the next one in the list (which is the previous day).
  return [
    for (int i = 0; i < checkins.length; i++)
      CheckinWithComparison(
        checkin: checkins[i],
        comparison: CheckinComparison(
          current: checkins[i],
          previous: i + 1 < checkins.length ? checkins[i + 1] : null,
        ),
      ),
  ];
}

/// Provides workout sessions for a specific client (trainer viewing)
@riverpod
Future<List<WorkoutSession>> clientWorkoutSessions(
  ClientWorkoutSessionsRef ref,
  String clientId,
) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final result = await repo.getClientWorkoutSessions(clientId, limit: 50);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (sessions) => sessions,
  );
}

/// Provides assigned plans for a specific client (trainer viewing)
@riverpod
Future<List<ClientPlan>> clientAssignedPlans(
  ClientAssignedPlansRef ref,
  String clientId,
) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final result = await repo.getClientPlans(clientId);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (plans) => plans,
  );
}

/// Notifier for managing client plan assignments (trainer actions)
@riverpod
class ClientPlanAssignmentNotifier extends _$ClientPlanAssignmentNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Assign a plan to a client
  Future<Either<Failure, ClientPlan>> assignPlan({
    required String planId,
    required String clientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncLoading();

    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.assignPlanToClient(
      planId: planId,
      clientId: clientId,
      startDate: startDate,
      endDate: endDate,
    );

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    // Refresh the client's assigned plans
    ref.invalidate(clientAssignedPlansProvider(clientId));

    return result;
  }

  /// Deactivate a client's plan
  Future<Either<Failure, Unit>> deactivatePlan({
    required String clientPlanId,
    required String clientId,
  }) async {
    state = const AsyncLoading();

    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.deactivateClientPlan(clientPlanId);

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    // Refresh the client's assigned plans
    ref.invalidate(clientAssignedPlansProvider(clientId));

    return result;
  }
}
