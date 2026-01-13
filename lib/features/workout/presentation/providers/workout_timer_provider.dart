import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/workout_session.dart';
import 'workout_provider.dart';

part 'workout_timer_provider.freezed.dart';
part 'workout_timer_provider.g.dart';

/// Stream that emits every second for timer updates
final _tickerProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (i) => i);
});

/// Global workout timer that tracks elapsed time.
@riverpod
Duration workoutTimer(Ref ref) {
  // Subscribe to ticker to get updates every second
  ref.watch(_tickerProvider);

  final workout = ref.watch(activeWorkoutNotifierProvider).valueOrNull;

  if (workout?.startedAt != null) {
    // Use UTC for both times to ensure correct timezone comparison
    final now = DateTime.now().toUtc();
    final startedAtUtc = workout!.startedAt!.toUtc();
    final elapsed = now.difference(startedAtUtc);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  return Duration.zero;
}

/// Rest timer state for global access
enum GlobalRestState { working, resting, ready, go }

/// Configuration for the rest timer context
@freezed
class RestTimerConfig with _$RestTimerConfig {
  const factory RestTimerConfig({
    required int minSeconds,
    required int maxSeconds,
    required DateTime lastSetCompletedAt,
  }) = _RestTimerConfig;
}

/// Context notifier that stores rest timer configuration
/// Keeps alive across navigation so rest state persists
@Riverpod(keepAlive: true)
class RestTimerContext extends _$RestTimerContext {
  @override
  RestTimerConfig? build() => null;

  /// Start rest timer with the completion timestamp
  void startRest({
    required int minSeconds,
    required int maxSeconds,
    required DateTime completedAt,
  }) {
    state = RestTimerConfig(
      minSeconds: minSeconds,
      maxSeconds: maxSeconds,
      lastSetCompletedAt: completedAt.toUtc(),
    );
  }

  /// Stop rest timer and return to working state
  void stopRest() {
    state = null;
  }

  /// Restore rest context from an active session's last completed set
  void restoreFromSession(WorkoutSession session) {
    DateTime? lastCompleted;
    int? restMin;
    int? restMax;

    // Find the most recently completed set across all exercises
    for (final log in session.exerciseLogs) {
      for (final set in log.setData) {
        if (set.completedAt != null) {
          if (lastCompleted == null ||
              set.completedAt!.isAfter(lastCompleted)) {
            lastCompleted = set.completedAt;
            restMin = log.targetRestMin;
            restMax = log.targetRestMax;
          }
        }
      }
    }

    if (lastCompleted != null && restMin != null) {
      state = RestTimerConfig(
        minSeconds: restMin,
        maxSeconds: restMax ?? restMin + 30,
        lastSetCompletedAt: lastCompleted.toUtc(),
      );
    }
  }
}

/// Computed rest state - derives everything from timestamps, no Timer needed
/// This provider re-evaluates every second via the ticker subscription
@riverpod
({GlobalRestState state, Duration elapsed, int minSeconds, int maxSeconds})
    computedRestState(Ref ref) {
  // Subscribe to ticker for updates every second
  ref.watch(_tickerProvider);

  final config = ref.watch(restTimerContextProvider);

  if (config == null) {
    return (
      state: GlobalRestState.working,
      elapsed: Duration.zero,
      minSeconds: 0,
      maxSeconds: 0,
    );
  }

  final now = DateTime.now().toUtc();
  final completedAtUtc = config.lastSetCompletedAt.toUtc();
  final elapsed = now.difference(completedAtUtc);
  final elapsedSeconds = elapsed.inSeconds;

  GlobalRestState restState;
  if (elapsedSeconds >= config.maxSeconds) {
    restState = GlobalRestState.go;
  } else if (elapsedSeconds >= config.minSeconds) {
    restState = GlobalRestState.ready;
  } else {
    restState = GlobalRestState.resting;
  }

  return (
    state: restState,
    elapsed: elapsed.isNegative ? Duration.zero : elapsed,
    minSeconds: config.minSeconds,
    maxSeconds: config.maxSeconds,
  );
}

/// Global rest timer provider - delegates to computedRestState for backward compatibility
/// UI components can continue to use globalRestTimerProvider
@riverpod
({GlobalRestState state, Duration elapsed, int minSeconds, int maxSeconds})
    globalRestTimer(Ref ref) {
  return ref.watch(computedRestStateProvider);
}

/// Helper extension to format duration as HH:MM:SS or MM:SS
extension DurationFormatting on Duration {
  String toWorkoutDisplay() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
