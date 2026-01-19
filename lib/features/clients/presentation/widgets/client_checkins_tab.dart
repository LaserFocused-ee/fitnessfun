import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../checkin/domain/entities/daily_checkin.dart';
import '../../../checkin/domain/utils/checkin_comparison.dart';
import '../../../checkin/presentation/widgets/delta_indicator.dart';
import '../providers/client_detail_provider.dart';

/// Tab displaying a client's check-in history for trainers.
class ClientCheckinsTab extends ConsumerWidget {
  const ClientCheckinsTab({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(clientCheckinsWithComparisonProvider(clientId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return checkinsAsync.when(
      data: (checkinsWithComparison) {
        if (checkinsWithComparison.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.checklist_outlined,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No check-ins yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Client has not submitted any check-ins',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: checkinsWithComparison.length,
          itemBuilder: (context, index) {
            final item = checkinsWithComparison[index];
            return _CheckinCard(
              checkin: item.checkin,
              comparison: item.comparison,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(clientCheckinsWithComparisonProvider(clientId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckinCard extends StatefulWidget {
  const _CheckinCard({
    required this.checkin,
    required this.comparison,
  });

  final DailyCheckin checkin;
  final CheckinComparison comparison;

  @override
  State<_CheckinCard> createState() => _CheckinCardState();
}

class _CheckinCardState extends State<_CheckinCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final checkin = widget.checkin;
    final comparison = widget.comparison;
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(checkin.date),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Key metrics summary with deltas
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (checkin.bodyweightKg != null)
                    _MetricChipWithDelta(
                      icon: Icons.monitor_weight_outlined,
                      label: '${checkin.bodyweightKg!.toStringAsFixed(1)} kg',
                      delta: comparison.weightDelta,
                    ),
                  if (checkin.steps != null)
                    _MetricChipWithDelta(
                      icon: Icons.directions_walk,
                      label: '${checkin.steps!} steps',
                      delta: comparison.stepsDelta,
                    ),
                  if (checkin.workoutPlanId != null)
                    const _MetricChip(
                      icon: Icons.fitness_center,
                      label: 'Trained',
                    ),
                ],
              ),

              // Expanded details
              if (_isExpanded) ...[
                const Divider(height: 24),
                _buildExpandedDetails(context, checkin, comparison),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDetails(
    BuildContext context,
    DailyCheckin checkin,
    CheckinComparison comparison,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Biometrics section
        if (checkin.bodyweightKg != null ||
            checkin.fluidIntakeLitres != null ||
            checkin.caffeineMg != null) ...[
          _SectionTitle(title: 'Biometrics'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (checkin.bodyweightKg != null)
                _DetailItemWithDelta(
                  label: 'Weight',
                  value: '${checkin.bodyweightKg!.toStringAsFixed(1)} kg',
                  delta: comparison.weightDelta,
                ),
              if (checkin.fluidIntakeLitres != null)
                _DetailItemWithDelta(
                  label: 'Fluids',
                  value: '${checkin.fluidIntakeLitres!.toStringAsFixed(1)} L',
                  delta: comparison.fluidsDelta,
                ),
              if (checkin.caffeineMg != null)
                _DetailItemWithDelta(
                  label: 'Caffeine',
                  value: '${checkin.caffeineMg} mg',
                  delta: comparison.caffeineDelta,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Activity section
        if (checkin.steps != null ||
            checkin.cardioMinutes != null ||
            checkin.workoutPlanId != null) ...[
          _SectionTitle(title: 'Activity'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (checkin.steps != null)
                _DetailItemWithDelta(
                  label: 'Steps',
                  value: '${checkin.steps}',
                  delta: comparison.stepsDelta,
                ),
              if (checkin.cardioMinutes != null)
                _DetailItemWithDelta(
                  label: 'Cardio',
                  value: '${checkin.cardioMinutes} min',
                  delta: comparison.cardioMinutesDelta,
                ),
              if (checkin.workoutPlanId != null)
                const _DetailItem(
                  label: 'Trained',
                  value: 'Yes',
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Recovery section
        if (checkin.performance != null ||
            checkin.energyLevels != null ||
            checkin.stressLevels != null ||
            checkin.sleepQuality != null) ...[
          _SectionTitle(title: 'Recovery Metrics'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (checkin.performance != null)
                _RatingItemWithDelta(
                  label: 'Performance',
                  rating: checkin.performance!,
                  delta: comparison.performanceDelta,
                ),
              if (checkin.energyLevels != null)
                _RatingItemWithDelta(
                  label: 'Energy',
                  rating: checkin.energyLevels!,
                  delta: comparison.energyLevelsDelta,
                ),
              if (checkin.stressLevels != null)
                _RatingItemWithDelta(
                  label: 'Stress',
                  rating: checkin.stressLevels!,
                  delta: comparison.stressLevelsDelta,
                ),
              if (checkin.muscleSoreness != null)
                _RatingItemWithDelta(
                  label: 'Soreness',
                  rating: checkin.muscleSoreness!,
                  delta: comparison.muscleSorenessDelta,
                ),
              if (checkin.recoveryRate != null)
                _RatingItemWithDelta(
                  label: 'Recovery',
                  rating: checkin.recoveryRate!,
                  delta: comparison.recoveryRateDelta,
                ),
              if (checkin.mentalHealth != null)
                _RatingItemWithDelta(
                  label: 'Mental Health',
                  rating: checkin.mentalHealth!,
                  delta: comparison.mentalHealthDelta,
                ),
              if (checkin.hungerLevels != null)
                _RatingItemWithDelta(
                  label: 'Hunger',
                  rating: checkin.hungerLevels!,
                  delta: comparison.hungerLevelsDelta,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Sleep section
        if (checkin.sleepDurationMinutes != null ||
            checkin.sleepQuality != null) ...[
          _SectionTitle(title: 'Sleep'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (checkin.sleepDurationMinutes != null)
                _DetailItemWithDelta(
                  label: 'Duration',
                  value: checkin.sleepFormatted ?? '-',
                  delta: comparison.sleepDurationDelta,
                ),
              if (checkin.sleepQuality != null)
                _RatingItemWithDelta(
                  label: 'Quality',
                  rating: checkin.sleepQuality!,
                  delta: comparison.sleepQualityDelta,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Notes section
        if (checkin.notes != null && checkin.notes!.isNotEmpty) ...[
          _SectionTitle(title: 'Notes'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              checkin.notes!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Text(
      title,
      style: theme.textTheme.labelMedium?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RatingItem extends StatelessWidget {
  const _RatingItem({required this.label, required this.rating});

  final String label;
  final int rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color ratingColor;
    if (rating <= 2) {
      ratingColor = Colors.red;
    } else if (rating <= 4) {
      ratingColor = Colors.orange;
    } else if (rating <= 5) {
      ratingColor = Colors.amber;
    } else {
      ratingColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$rating',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: ratingColor,
              ),
            ),
            Text(
              '/7',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Metric chip with delta indicator for summary view.
class _MetricChipWithDelta extends StatelessWidget {
  const _MetricChipWithDelta({
    required this.icon,
    required this.label,
    required this.delta,
  });

  final IconData icon;
  final String label;
  final MetricDelta delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        if (delta.hasValue) ...[
          const SizedBox(width: 4),
          DeltaIndicator(delta: delta, compact: true),
        ],
      ],
    );
  }
}

/// Detail item with delta indicator for expanded view.
class _DetailItemWithDelta extends StatelessWidget {
  const _DetailItemWithDelta({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final MetricDelta delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (delta.hasValue) ...[
              const SizedBox(width: 6),
              DeltaIndicator(delta: delta),
            ],
          ],
        ),
      ],
    );
  }
}

/// Rating item with delta indicator for expanded view.
class _RatingItemWithDelta extends StatelessWidget {
  const _RatingItemWithDelta({
    required this.label,
    required this.rating,
    required this.delta,
  });

  final String label;
  final int rating;
  final MetricDelta delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color ratingColor;
    if (rating <= 2) {
      ratingColor = Colors.red;
    } else if (rating <= 4) {
      ratingColor = Colors.orange;
    } else if (rating <= 5) {
      ratingColor = Colors.amber;
    } else {
      ratingColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$rating',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: ratingColor,
              ),
            ),
            Text(
              '/7',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (delta.hasValue) ...[
              const SizedBox(width: 6),
              DeltaIndicator(delta: delta),
            ],
          ],
        ),
      ],
    );
  }
}
