import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/daily_checkin.dart';

/// Abstract repository for daily check-in operations.
abstract class CheckinRepository {
  /// Get all check-ins for a client within a date range.
  Future<Either<Failure, List<DailyCheckin>>> getCheckins({
    required String clientId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get a single check-in by date.
  Future<Either<Failure, DailyCheckin?>> getCheckinByDate({
    required String clientId,
    required DateTime date,
  });

  /// Save (create or update) a check-in.
  Future<Either<Failure, DailyCheckin>> saveCheckin(DailyCheckin checkin);

  /// Delete a check-in.
  Future<Either<Failure, Unit>> deleteCheckin(String id);

  /// Get weekly averages for metrics.
  Future<Either<Failure, Map<String, double>>> getWeeklyAverages({
    required String clientId,
    required DateTime weekStart,
  });
}
