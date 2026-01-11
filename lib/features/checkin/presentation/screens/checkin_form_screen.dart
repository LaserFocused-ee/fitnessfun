import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/rating_slider.dart';
import '../providers/checkin_provider.dart';

/// Daily check-in form screen.
class CheckinFormScreen extends ConsumerWidget {
  const CheckinFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinAsync = ref.watch(checkinFormNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Check-in'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final result =
                  await ref.read(checkinFormNotifierProvider.notifier).save();
              result.fold(
                (failure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(failure.displayMessage),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
                (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Check-in saved!')),
                  );
                  Navigator.of(context).pop();
                },
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: checkinAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (checkin) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date display
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    'Today - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  ),
                ),
              ),
              const Gap(24),

              // Biometrics Section
              _SectionHeader(title: 'Biometrics'),
              const Gap(12),
              _NumberField(
                label: 'Bodyweight (kg)',
                value: checkin.bodyweightKg,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateBodyweight(v),
                icon: Icons.monitor_weight_outlined,
              ),
              const Gap(12),
              _NumberField(
                label: 'Fluid Intake (L)',
                value: checkin.fluidIntakeLitres,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateFluidIntake(v),
                icon: Icons.water_drop_outlined,
              ),
              const Gap(12),
              _IntField(
                label: 'Caffeine (mg)',
                value: checkin.caffeineMg,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateCaffeine(v),
                icon: Icons.coffee_outlined,
              ),
              const Gap(24),

              // Activity Section
              _SectionHeader(title: 'Activity'),
              const Gap(12),
              _IntField(
                label: 'Steps',
                value: checkin.steps,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateSteps(v),
                icon: Icons.directions_walk_outlined,
              ),
              const Gap(12),
              _IntField(
                label: 'Cardio (minutes)',
                value: checkin.cardioMinutes,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateCardioMinutes(v),
                icon: Icons.directions_run_outlined,
              ),
              const Gap(12),
              _TextField(
                label: 'Training Session',
                value: checkin.trainingSession,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateTrainingSession(v),
                icon: Icons.fitness_center_outlined,
                hint: 'e.g., Upper 1, Lower 2',
              ),
              const Gap(24),

              // Recovery Section
              _SectionHeader(title: 'Recovery & Wellness'),
              const Gap(12),
              RatingSlider(
                label: 'Performance',
                value: checkin.performance,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updatePerformance(v),
              ),
              const Gap(12),
              RatingSlider(
                label: 'Muscle Soreness',
                value: checkin.muscleSoreness,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateMuscleSoreness(v),
                lowLabel: 'None',
                highLabel: 'Very Sore',
              ),
              const Gap(12),
              RatingSlider(
                label: 'Energy Levels',
                value: checkin.energyLevels,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateEnergyLevels(v),
              ),
              const Gap(12),
              RatingSlider(
                label: 'Recovery Rate',
                value: checkin.recoveryRate,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateRecoveryRate(v),
              ),
              const Gap(12),
              RatingSlider(
                label: 'Stress Levels',
                value: checkin.stressLevels,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateStressLevels(v),
                lowLabel: 'Low',
                highLabel: 'High',
                invertColors: true,
              ),
              const Gap(12),
              RatingSlider(
                label: 'Mental Health',
                value: checkin.mentalHealth,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateMentalHealth(v),
                lowLabel: 'Poor',
                highLabel: 'Great',
              ),
              const Gap(12),
              RatingSlider(
                label: 'Hunger Levels',
                value: checkin.hungerLevels,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateHungerLevels(v),
              ),
              const Gap(24),

              // Health Section
              _SectionHeader(title: 'Health'),
              const Gap(12),
              SwitchListTile(
                title: const Text('Illness'),
                subtitle: const Text('Are you feeling unwell?'),
                value: checkin.illness,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateIllness(v),
              ),
              const Gap(12),
              _TextField(
                label: 'GI Distress',
                value: checkin.giDistress,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateGiDistress(v),
                icon: Icons.sick_outlined,
                hint: 'Any digestive issues?',
                maxLines: 2,
              ),
              const Gap(24),

              // Sleep Section
              _SectionHeader(title: 'Sleep'),
              const Gap(12),
              _SleepDurationField(
                value: checkin.sleepDurationMinutes,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateSleepDuration(v),
              ),
              const Gap(12),
              RatingSlider(
                label: 'Sleep Quality',
                value: checkin.sleepQuality,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateSleepQuality(v),
                lowLabel: 'Poor',
                highLabel: 'Great',
              ),
              const Gap(24),

              // Notes Section
              _SectionHeader(title: 'Notes'),
              const Gap(12),
              _TextField(
                label: 'Additional Notes',
                value: checkin.notes,
                onChanged: (v) => ref
                    .read(checkinFormNotifierProvider.notifier)
                    .updateNotes(v),
                icon: Icons.notes_outlined,
                hint: 'Any other observations...',
                maxLines: 4,
              ),
              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primary,
          ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final double? value;
  final void Function(double?) onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => onChanged(double.tryParse(v)),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final int? value;
  final void Function(int?) onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) => onChanged(int.tryParse(v)),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.hint,
    this.maxLines = 1,
  });

  final String label;
  final String? value;
  final void Function(String?) onChanged;
  final IconData icon;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value ?? '',
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      maxLines: maxLines,
      onChanged: (v) => onChanged(v.isEmpty ? null : v),
    );
  }
}

class _SleepDurationField extends StatelessWidget {
  const _SleepDurationField({
    required this.value,
    required this.onChanged,
  });

  final int? value;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    final hours = value != null ? value! ~/ 60 : 7;
    final minutes = value != null ? value! % 60 : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime_outlined),
                const SizedBox(width: 8),
                const Text('Sleep Duration'),
                const Spacer(),
                Text(
                  '${hours}h ${minutes}m',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hours'),
                      Slider(
                        value: hours.toDouble(),
                        min: 0,
                        max: 12,
                        divisions: 12,
                        onChanged: (v) {
                          onChanged(v.toInt() * 60 + minutes);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Minutes'),
                      Slider(
                        value: minutes.toDouble(),
                        min: 0,
                        max: 55,
                        divisions: 11,
                        onChanged: (v) {
                          onChanged(hours * 60 + v.toInt());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
