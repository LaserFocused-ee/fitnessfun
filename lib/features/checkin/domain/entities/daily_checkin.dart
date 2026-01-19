import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_checkin.freezed.dart';
part 'daily_checkin.g.dart';

/// Daily check-in entity matching the database schema.
@freezed
class DailyCheckin with _$DailyCheckin {
  const factory DailyCheckin({
    required String id,
    required String clientId,
    required DateTime date,

    // Biometrics
    double? bodyweightKg,
    double? fluidIntakeLitres,
    int? caffeineMg,

    // Activity
    int? steps,
    int? cardioMinutes,
    String? workoutPlanId,

    // Recovery metrics (1-7 scale)
    int? performance,
    int? muscleSoreness,
    int? energyLevels,
    int? recoveryRate,
    int? stressLevels,
    int? mentalHealth,
    int? hungerLevels,

    // Health
    @Default(false) bool illness,
    String? giDistress,

    // Sleep
    int? sleepDurationMinutes,
    int? sleepQuality,

    // Notes
    String? notes,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _DailyCheckin;

  /// Create an empty check-in for a given date (defaults to today).
  factory DailyCheckin.empty({required String clientId, DateTime? date}) =>
      DailyCheckin(
        id: '',
        clientId: clientId,
        date: date ?? DateTime.now(),
      );

  factory DailyCheckin.fromJson(Map<String, dynamic> json) =>
      _$DailyCheckinFromJson(json);
}

/// Extension for sleep duration formatting.
extension DailyCheckinX on DailyCheckin {
  /// Get sleep duration as Duration.
  Duration? get sleepDuration {
    if (sleepDurationMinutes == null) return null;
    return Duration(minutes: sleepDurationMinutes!);
  }

  /// Format sleep as "Xh Ym".
  String? get sleepFormatted {
    if (sleepDurationMinutes == null) return null;
    final hours = sleepDurationMinutes! ~/ 60;
    final minutes = sleepDurationMinutes! % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }
}
