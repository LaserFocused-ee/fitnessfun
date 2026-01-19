import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/checkin_repository_impl.dart';
import '../../domain/entities/daily_checkin.dart';
import '../../domain/repositories/checkin_repository.dart';

part 'checkin_provider.g.dart';

/// Provides the checkin repository instance.
@riverpod
CheckinRepository checkinRepository(CheckinRepositoryRef ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseCheckinRepository(client);
}

/// Provides check-ins for the current user with optional date range.
@riverpod
Future<List<DailyCheckin>> checkins(
  CheckinsRef ref, {
  DateTime? startDate,
  DateTime? endDate,
}) async {
  final repo = ref.watch(checkinRepositoryProvider);
  final profile = await ref.watch(currentProfileProvider.future);

  if (profile == null) return [];

  final result = await repo.getCheckins(
    clientId: profile.id,
    startDate: startDate,
    endDate: endDate,
  );

  return result.fold(
    (failure) => throw failure,
    (checkins) => checkins,
  );
}

/// Provides today's check-in for the current user.
@riverpod
Future<DailyCheckin?> todayCheckin(TodayCheckinRef ref) async {
  final repo = ref.watch(checkinRepositoryProvider);
  final profile = await ref.watch(currentProfileProvider.future);

  if (profile == null) return null;

  final result = await repo.getCheckinByDate(
    clientId: profile.id,
    date: DateTime.now(),
  );

  return result.fold(
    (failure) => throw failure,
    (checkin) => checkin,
  );
}

/// Provides a check-in for a specific date.
@riverpod
Future<DailyCheckin?> checkinByDate(CheckinByDateRef ref, DateTime date) async {
  final repo = ref.watch(checkinRepositoryProvider);
  final profile = await ref.watch(currentProfileProvider.future);

  if (profile == null) return null;

  final result = await repo.getCheckinByDate(
    clientId: profile.id,
    date: date,
  );

  return result.fold(
    (failure) => throw failure,
    (checkin) => checkin,
  );
}

/// Notifier for managing the check-in form state.
/// Accepts an optional date parameter - defaults to today.
@riverpod
class CheckinFormNotifier extends _$CheckinFormNotifier {
  DateTime _selectedDate = DateTime.now();

  @override
  Future<DailyCheckin> build() async {
    return _loadCheckinForDate(_selectedDate);
  }

  Future<DailyCheckin> _loadCheckinForDate(DateTime date) async {
    final profile = await ref.read(currentProfileProvider.future);
    final repo = ref.read(checkinRepositoryProvider);

    final result = await repo.getCheckinByDate(
      clientId: profile?.id ?? '',
      date: date,
    );

    return result.fold(
      (failure) => DailyCheckin.empty(clientId: profile?.id ?? '', date: date),
      (checkin) => checkin ?? DailyCheckin.empty(clientId: profile?.id ?? '', date: date),
    );
  }

  CheckinRepository get _repo => ref.read(checkinRepositoryProvider);

  /// Get the currently selected date.
  DateTime get selectedDate => _selectedDate;

  /// Change the date and load/create check-in for that date.
  Future<void> changeDate(DateTime newDate) async {
    _selectedDate = newDate;
    state = const AsyncLoading();
    final checkin = await _loadCheckinForDate(newDate);
    state = AsyncData(checkin);
  }

  /// Update a field in the check-in.
  void updateField<T>(T? Function(DailyCheckin) getter, DailyCheckin Function(T?) updater) {
    state.whenData((checkin) {
      state = AsyncData(updater(getter(checkin)));
    });
  }

  /// Update bodyweight.
  void updateBodyweight(double? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(bodyweightKg: value));
    });
  }

  /// Update fluid intake.
  void updateFluidIntake(double? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(fluidIntakeLitres: value));
    });
  }

  /// Update caffeine.
  void updateCaffeine(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(caffeineMg: value));
    });
  }

  /// Update steps.
  void updateSteps(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(steps: value));
    });
  }

  /// Update cardio minutes.
  void updateCardioMinutes(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(cardioMinutes: value));
    });
  }

  /// Update workout plan ID.
  void updateWorkoutPlanId(String? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(workoutPlanId: value));
    });
  }

  /// Update performance rating.
  void updatePerformance(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(performance: value));
    });
  }

  /// Update muscle soreness rating.
  void updateMuscleSoreness(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(muscleSoreness: value));
    });
  }

  /// Update energy levels rating.
  void updateEnergyLevels(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(energyLevels: value));
    });
  }

  /// Update recovery rate rating.
  void updateRecoveryRate(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(recoveryRate: value));
    });
  }

  /// Update stress levels rating.
  void updateStressLevels(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(stressLevels: value));
    });
  }

  /// Update mental health rating.
  void updateMentalHealth(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(mentalHealth: value));
    });
  }

  /// Update hunger levels rating.
  void updateHungerLevels(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(hungerLevels: value));
    });
  }

  /// Update illness status.
  void updateIllness(bool value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(illness: value));
    });
  }

  /// Update GI distress notes.
  void updateGiDistress(String? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(giDistress: value));
    });
  }

  /// Update sleep duration in minutes.
  void updateSleepDuration(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(sleepDurationMinutes: value));
    });
  }

  /// Update sleep quality rating.
  void updateSleepQuality(int? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(sleepQuality: value));
    });
  }

  /// Update notes.
  void updateNotes(String? value) {
    state.whenData((checkin) {
      state = AsyncData(checkin.copyWith(notes: value));
    });
  }

  /// Save the check-in.
  Future<Either<Failure, DailyCheckin>> save() async {
    final checkin = state.valueOrNull;
    if (checkin == null) {
      return left(const Failure.validation(message: 'No check-in data'));
    }

    final result = await _repo.saveCheckin(checkin);

    result.fold(
      (failure) => null,
      (saved) {
        // Don't update state here - let the screen pop and next time
        // it opens it will fetch fresh data from todayCheckinProvider
        ref.invalidate(checkinsProvider);
        ref.invalidate(todayCheckinProvider);
      },
    );

    return result;
  }
}
