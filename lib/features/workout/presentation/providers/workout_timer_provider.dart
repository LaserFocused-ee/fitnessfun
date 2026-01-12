import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'workout_provider.dart';

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

/// Global rest timer state - keeps alive across navigation
@Riverpod(keepAlive: true)
class GlobalRestTimer extends _$GlobalRestTimer {
  Timer? _timer;

  @override
  ({GlobalRestState state, Duration elapsed, int minSeconds, int maxSeconds}) build() {
    ref.onDispose(() => _timer?.cancel());
    return (state: GlobalRestState.working, elapsed: Duration.zero, minSeconds: 0, maxSeconds: 0);
  }

  void startRest(int minSeconds, int maxSeconds) {
    _timer?.cancel();
    state = (state: GlobalRestState.resting, elapsed: Duration.zero, minSeconds: minSeconds, maxSeconds: maxSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final newElapsed = state.elapsed + const Duration(seconds: 1);
      final restSeconds = newElapsed.inSeconds;

      GlobalRestState newState;
      if (restSeconds >= state.maxSeconds) {
        newState = GlobalRestState.go;
      } else if (restSeconds >= state.minSeconds) {
        newState = GlobalRestState.ready;
      } else {
        newState = GlobalRestState.resting;
      }

      state = (state: newState, elapsed: newElapsed, minSeconds: state.minSeconds, maxSeconds: state.maxSeconds);
    });
  }

  void stopRest() {
    _timer?.cancel();
    state = (state: GlobalRestState.working, elapsed: Duration.zero, minSeconds: 0, maxSeconds: 0);
  }
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
