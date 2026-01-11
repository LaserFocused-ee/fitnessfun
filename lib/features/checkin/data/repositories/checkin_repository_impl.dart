import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/daily_checkin.dart';
import '../../domain/repositories/checkin_repository.dart';

/// Supabase implementation of [CheckinRepository].
class SupabaseCheckinRepository implements CheckinRepository {
  SupabaseCheckinRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<DailyCheckin>>> getCheckins({
    required String clientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('daily_checkins')
          .select()
          .eq('client_id', clientId);

      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('date', ascending: false);
      final checkins = (response as List)
          .map((json) => DailyCheckin.fromJson(json as Map<String, dynamic>))
          .toList();

      return right(checkins);
    } on PostgrestException catch (e) {
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, DailyCheckin?>> getCheckinByDate({
    required String clientId,
    required DateTime date,
  }) async {
    try {
      final dateString = date.toIso8601String().split('T')[0];

      final response = await _client
          .from('daily_checkins')
          .select()
          .eq('client_id', clientId)
          .eq('date', dateString)
          .maybeSingle();

      if (response == null) {
        return right(null);
      }

      return right(DailyCheckin.fromJson(response));
    } on PostgrestException catch (e) {
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, DailyCheckin>> saveCheckin(DailyCheckin checkin) async {
    try {
      final data = checkin.toJson()
        ..remove('id')
        ..remove('created_at')
        ..remove('updated_at');

      // Convert date to string format
      data['date'] = (checkin.date).toIso8601String().split('T')[0];

      if (checkin.id.isEmpty) {
        // Create new
        final response = await _client
            .from('daily_checkins')
            .insert(data)
            .select()
            .single();
        return right(DailyCheckin.fromJson(response));
      } else {
        // Update existing
        final response = await _client
            .from('daily_checkins')
            .update(data)
            .eq('id', checkin.id)
            .select()
            .single();
        return right(DailyCheckin.fromJson(response));
      }
    } on PostgrestException catch (e) {
      // Handle unique constraint (upsert on date)
      if (e.code == '23505') {
        // Unique violation - try upsert
        try {
          final data = checkin.toJson()
            ..remove('id')
            ..remove('created_at')
            ..remove('updated_at');
          data['date'] = (checkin.date).toIso8601String().split('T')[0];

          final response = await _client
              .from('daily_checkins')
              .upsert(data, onConflict: 'client_id,date')
              .select()
              .single();
          return right(DailyCheckin.fromJson(response));
        } catch (e2) {
          return left(Failure.server(message: e.message, code: e.code));
        }
      }
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteCheckin(String id) async {
    try {
      await _client.from('daily_checkins').delete().eq('id', id);
      return right(unit);
    } on PostgrestException catch (e) {
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> getWeeklyAverages({
    required String clientId,
    required DateTime weekStart,
  }) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 6));

      final response = await _client
          .from('daily_checkins')
          .select()
          .eq('client_id', clientId)
          .gte('date', weekStart.toIso8601String().split('T')[0])
          .lte('date', weekEnd.toIso8601String().split('T')[0]);

      final checkins = (response as List)
          .map((json) => DailyCheckin.fromJson(json as Map<String, dynamic>))
          .toList();

      if (checkins.isEmpty) {
        return right({});
      }

      // Calculate averages
      final averages = <String, double>{};

      double _avg(Iterable<num?> values) {
        final nonNull = values.whereType<num>().toList();
        if (nonNull.isEmpty) return 0;
        return nonNull.reduce((a, b) => a + b) / nonNull.length;
      }

      averages['bodyweight'] = _avg(checkins.map((c) => c.bodyweightKg));
      averages['fluidIntake'] = _avg(checkins.map((c) => c.fluidIntakeLitres));
      averages['steps'] = _avg(checkins.map((c) => c.steps));
      averages['cardioMinutes'] = _avg(checkins.map((c) => c.cardioMinutes));
      averages['performance'] = _avg(checkins.map((c) => c.performance));
      averages['energyLevels'] = _avg(checkins.map((c) => c.energyLevels));
      averages['stressLevels'] = _avg(checkins.map((c) => c.stressLevels));
      averages['sleepQuality'] = _avg(checkins.map((c) => c.sleepQuality));

      return right(averages);
    } on PostgrestException catch (e) {
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }
}
