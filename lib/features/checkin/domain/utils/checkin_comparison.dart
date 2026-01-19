import '../entities/daily_checkin.dart';

/// Direction of change from previous to current.
enum DeltaDirection {
  up,
  down,
  neutral,
}

/// Configuration for what direction is considered "positive" for a metric.
enum DeltaPositivity {
  /// Higher values are good (e.g., steps, energy levels)
  upIsGood,

  /// Lower values are good (e.g., stress, soreness)
  downIsGood,

  /// Direction doesn't indicate good/bad (e.g., bodyweight - context dependent)
  contextDependent,
}

/// Represents a comparison between two checkin values.
class MetricDelta {
  const MetricDelta({
    required this.value,
    required this.direction,
    required this.displayText,
    required this.positivity,
  });

  /// Creates an empty delta (no previous value to compare against).
  const MetricDelta.empty()
      : value = null,
        direction = DeltaDirection.neutral,
        displayText = '',
        positivity = DeltaPositivity.contextDependent;

  /// The numeric delta value (null if no previous).
  final double? value;

  /// Direction of change: up, down, or neutral.
  final DeltaDirection direction;

  /// Display string like "+1.2 kg", "-500", "+2".
  final String displayText;

  /// Whether the direction is positive, negative, or context-dependent.
  final DeltaPositivity positivity;

  /// Whether this delta has a value (not empty).
  bool get hasValue => value != null;

  /// Whether this is a positive change (green coloring).
  bool get isPositive {
    if (direction == DeltaDirection.neutral) return false;

    switch (positivity) {
      case DeltaPositivity.upIsGood:
        return direction == DeltaDirection.up;
      case DeltaPositivity.downIsGood:
        return direction == DeltaDirection.down;
      case DeltaPositivity.contextDependent:
        return false; // Will use neutral coloring
    }
  }

  /// Whether this is a negative change (red coloring).
  bool get isNegative {
    if (direction == DeltaDirection.neutral) return false;

    switch (positivity) {
      case DeltaPositivity.upIsGood:
        return direction == DeltaDirection.down;
      case DeltaPositivity.downIsGood:
        return direction == DeltaDirection.up;
      case DeltaPositivity.contextDependent:
        return false; // Will use neutral coloring
    }
  }
}

/// Thresholds to avoid noise from minor fluctuations.
class _Thresholds {
  static const double weight = 0.2; // kg
  static const int steps = 500;
  static const int rating = 1;
  static const int sleepMinutes = 15;
  static const int cardioMinutes = 5;
  static const double fluids = 0.2; // L
  static const int caffeine = 25; // mg
}

/// Calculates deltas between current and previous checkin.
class CheckinComparison {
  CheckinComparison({
    required this.current,
    required this.previous,
  });

  final DailyCheckin current;
  final DailyCheckin? previous;

  /// Whether there's a previous checkin to compare against.
  bool get hasPrevious => previous != null;

  // --- Biometrics ---

  MetricDelta get weightDelta => _calculateDelta(
        current: current.bodyweightKg,
        previous: previous?.bodyweightKg,
        threshold: _Thresholds.weight,
        positivity: DeltaPositivity.contextDependent,
        unit: '',
        decimals: 1,
      );

  MetricDelta get fluidsDelta => _calculateDelta(
        current: current.fluidIntakeLitres,
        previous: previous?.fluidIntakeLitres,
        threshold: _Thresholds.fluids,
        positivity: DeltaPositivity.upIsGood,
        unit: '',
        decimals: 1,
      );

  MetricDelta get caffeineDelta => _calculateDelta(
        current: current.caffeineMg?.toDouble(),
        previous: previous?.caffeineMg?.toDouble(),
        threshold: _Thresholds.caffeine.toDouble(),
        positivity: DeltaPositivity.downIsGood,
        unit: '',
        decimals: 0,
      );

  // --- Activity ---

  MetricDelta get stepsDelta => _calculateDelta(
        current: current.steps?.toDouble(),
        previous: previous?.steps?.toDouble(),
        threshold: _Thresholds.steps.toDouble(),
        positivity: DeltaPositivity.upIsGood,
        unit: '',
        decimals: 0,
      );

  MetricDelta get cardioMinutesDelta => _calculateDelta(
        current: current.cardioMinutes?.toDouble(),
        previous: previous?.cardioMinutes?.toDouble(),
        threshold: _Thresholds.cardioMinutes.toDouble(),
        positivity: DeltaPositivity.upIsGood,
        unit: '',
        decimals: 0,
      );

  /// Whether client trained (had a workout plan) - returns a special delta.
  MetricDelta get trainedDelta {
    if (previous == null) return const MetricDelta.empty();

    final currentTrained = current.workoutPlanId != null;
    final previousTrained = previous!.workoutPlanId != null;

    if (currentTrained == previousTrained) {
      return const MetricDelta.empty();
    }

    if (currentTrained && !previousTrained) {
      return const MetricDelta(
        value: 1,
        direction: DeltaDirection.up,
        displayText: 'Yes',
        positivity: DeltaPositivity.upIsGood,
      );
    } else {
      return const MetricDelta(
        value: -1,
        direction: DeltaDirection.down,
        displayText: 'No',
        positivity: DeltaPositivity.upIsGood,
      );
    }
  }

  // --- Recovery (1-7 scale) ---

  MetricDelta get performanceDelta => _calculateRatingDelta(
        current: current.performance,
        previous: previous?.performance,
        positivity: DeltaPositivity.upIsGood,
      );

  MetricDelta get muscleSorenessDelta => _calculateRatingDelta(
        current: current.muscleSoreness,
        previous: previous?.muscleSoreness,
        positivity: DeltaPositivity.downIsGood,
      );

  MetricDelta get energyLevelsDelta => _calculateRatingDelta(
        current: current.energyLevels,
        previous: previous?.energyLevels,
        positivity: DeltaPositivity.upIsGood,
      );

  MetricDelta get recoveryRateDelta => _calculateRatingDelta(
        current: current.recoveryRate,
        previous: previous?.recoveryRate,
        positivity: DeltaPositivity.upIsGood,
      );

  MetricDelta get stressLevelsDelta => _calculateRatingDelta(
        current: current.stressLevels,
        previous: previous?.stressLevels,
        positivity: DeltaPositivity.downIsGood,
      );

  MetricDelta get mentalHealthDelta => _calculateRatingDelta(
        current: current.mentalHealth,
        previous: previous?.mentalHealth,
        positivity: DeltaPositivity.upIsGood,
      );

  MetricDelta get hungerLevelsDelta => _calculateRatingDelta(
        current: current.hungerLevels,
        previous: previous?.hungerLevels,
        positivity: DeltaPositivity.downIsGood,
      );

  // --- Sleep ---

  MetricDelta get sleepDurationDelta => _calculateDelta(
        current: current.sleepDurationMinutes?.toDouble(),
        previous: previous?.sleepDurationMinutes?.toDouble(),
        threshold: _Thresholds.sleepMinutes.toDouble(),
        positivity: DeltaPositivity.upIsGood,
        unit: '',
        decimals: 0,
      );

  MetricDelta get sleepQualityDelta => _calculateRatingDelta(
        current: current.sleepQuality,
        previous: previous?.sleepQuality,
        positivity: DeltaPositivity.upIsGood,
      );

  // --- Health ---

  MetricDelta get illnessDelta {
    if (previous == null) return const MetricDelta.empty();

    final currentIll = current.illness;
    final previousIll = previous!.illness;

    if (currentIll == previousIll) {
      return const MetricDelta.empty();
    }

    if (!currentIll && previousIll) {
      // Recovered - good!
      return const MetricDelta(
        value: -1,
        direction: DeltaDirection.down,
        displayText: 'Recovered',
        positivity: DeltaPositivity.downIsGood,
      );
    } else {
      // Got sick - bad
      return const MetricDelta(
        value: 1,
        direction: DeltaDirection.up,
        displayText: 'Sick',
        positivity: DeltaPositivity.downIsGood,
      );
    }
  }

  // --- Helper methods ---

  MetricDelta _calculateDelta({
    required double? current,
    required double? previous,
    required double threshold,
    required DeltaPositivity positivity,
    required String unit,
    required int decimals,
  }) {
    if (current == null || previous == null) {
      return const MetricDelta.empty();
    }

    final delta = current - previous;
    final absDelta = delta.abs();

    if (absDelta < threshold) {
      return const MetricDelta.empty();
    }

    final direction = delta > 0 ? DeltaDirection.up : DeltaDirection.down;
    final sign = delta > 0 ? '+' : '';
    final displayValue = decimals == 0 ? delta.round().toString() : delta.toStringAsFixed(decimals);
    final displayText = '$sign$displayValue$unit';

    return MetricDelta(
      value: delta,
      direction: direction,
      displayText: displayText,
      positivity: positivity,
    );
  }

  MetricDelta _calculateRatingDelta({
    required int? current,
    required int? previous,
    required DeltaPositivity positivity,
  }) {
    if (current == null || previous == null) {
      return const MetricDelta.empty();
    }

    final delta = current - previous;

    if (delta.abs() < _Thresholds.rating) {
      return const MetricDelta.empty();
    }

    final direction = delta > 0 ? DeltaDirection.up : DeltaDirection.down;
    final sign = delta > 0 ? '+' : '';
    final displayText = '$sign$delta';

    return MetricDelta(
      value: delta.toDouble(),
      direction: direction,
      displayText: displayText,
      positivity: positivity,
    );
  }
}

/// Container for a checkin paired with its comparison data.
class CheckinWithComparison {
  const CheckinWithComparison({
    required this.checkin,
    required this.comparison,
  });

  final DailyCheckin checkin;
  final CheckinComparison comparison;
}
