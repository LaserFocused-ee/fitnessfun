import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/widgets/rating_slider.dart';
import '../providers/checkin_provider.dart';
import '../widgets/checkin_form_widgets.dart';

/// Daily check-in form screen.
class CheckinFormScreen extends ConsumerWidget {
  const CheckinFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinAsync = ref.watch(checkinFormNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Check-in'),
        actions: [
          TextButton.icon(
            onPressed: () => _saveCheckin(context, ref),
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
              // Date picker
              Card(
                child: ListTile(
                  leading: Icon(Icons.calendar_today, color: colorScheme.primary),
                  title: Text(
                    _formatDate(checkin.date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: _isToday(checkin.date)
                      ? const Text('Today')
                      : Text(_getDayDifference(checkin.date)),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () => _selectDate(context, ref, checkin.date),
                ),
              ),
              const Gap(24),

              // Biometrics Section
              const CheckinSectionHeader(title: 'Biometrics'),
              const Gap(12),
              CheckinNumberField(
                label: 'Bodyweight (kg)',
                value: checkin.bodyweightKg,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateBodyweight,
                icon: Icons.monitor_weight_outlined,
              ),
              const Gap(12),
              CheckinNumberField(
                label: 'Fluid Intake (L)',
                value: checkin.fluidIntakeLitres,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateFluidIntake,
                icon: Icons.water_drop_outlined,
              ),
              const Gap(12),
              CheckinIntField(
                label: 'Caffeine (mg)',
                value: checkin.caffeineMg,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateCaffeine,
                icon: Icons.coffee_outlined,
              ),
              const Gap(24),

              // Activity Section
              const CheckinSectionHeader(title: 'Activity'),
              const Gap(12),
              CheckinIntField(
                label: 'Steps',
                value: checkin.steps,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateSteps,
                icon: Icons.directions_walk_outlined,
              ),
              const Gap(12),
              CheckinIntField(
                label: 'Cardio (minutes)',
                value: checkin.cardioMinutes,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateCardioMinutes,
                icon: Icons.directions_run_outlined,
              ),
              const Gap(12),
              WorkoutPlanDropdown(
                value: checkin.workoutPlanId,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateWorkoutPlanId,
              ),
              const Gap(24),

              // Recovery Section
              const CheckinSectionHeader(title: 'Recovery & Wellness'),
              const Gap(12),
              RatingSlider(
                label: 'Performance',
                value: checkin.performance,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updatePerformance,
              ),
              const Gap(12),
              RatingSlider(
                label: 'Muscle Soreness',
                value: checkin.muscleSoreness,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateMuscleSoreness,
                lowLabel: 'None',
                highLabel: 'Very Sore',
              ),
              const Gap(12),
              RatingSlider(
                label: 'Energy Levels',
                value: checkin.energyLevels,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateEnergyLevels,
              ),
              const Gap(12),
              RatingSlider(
                label: 'Recovery Rate',
                value: checkin.recoveryRate,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateRecoveryRate,
              ),
              const Gap(12),
              RatingSlider(
                label: 'Stress Levels',
                value: checkin.stressLevels,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateStressLevels,
                lowLabel: 'Low',
                highLabel: 'High',
                invertColors: true,
              ),
              const Gap(12),
              RatingSlider(
                label: 'Mental Health',
                value: checkin.mentalHealth,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateMentalHealth,
                lowLabel: 'Poor',
                highLabel: 'Great',
              ),
              const Gap(12),
              RatingSlider(
                label: 'Hunger Levels',
                value: checkin.hungerLevels,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateHungerLevels,
              ),
              const Gap(24),

              // Health Section
              const CheckinSectionHeader(title: 'Health'),
              const Gap(12),
              SwitchListTile(
                title: const Text('Illness'),
                subtitle: const Text('Are you feeling unwell?'),
                value: checkin.illness,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateIllness,
              ),
              const Gap(12),
              CheckinTextField(
                label: 'GI Distress',
                value: checkin.giDistress,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateGiDistress,
                icon: Icons.sick_outlined,
                hint: 'Any digestive issues?',
                maxLines: 2,
              ),
              const Gap(24),

              // Sleep Section
              const CheckinSectionHeader(title: 'Sleep'),
              const Gap(12),
              SleepDurationField(
                value: checkin.sleepDurationMinutes,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateSleepDuration,
              ),
              const Gap(12),
              RatingSlider(
                label: 'Sleep Quality',
                value: checkin.sleepQuality,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateSleepQuality,
                lowLabel: 'Poor',
                highLabel: 'Great',
              ),
              const Gap(24),

              // Notes Section
              const CheckinSectionHeader(title: 'Notes'),
              const Gap(12),
              CheckinTextField(
                label: 'Additional Notes',
                value: checkin.notes,
                onChanged: ref.read(checkinFormNotifierProvider.notifier).updateNotes,
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

  Future<void> _saveCheckin(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(checkinFormNotifierProvider.notifier).save();

    if (!context.mounted) return;

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
        context.go(AppRoutes.home);
      },
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    WidgetRef ref,
    DateTime currentDate,
  ) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: 'Select check-in date',
    );

    if (selected != null && context.mounted) {
      await ref.read(checkinFormNotifierProvider.notifier).changeDate(selected);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _getDayDifference(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkinDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(checkinDay).inDays;

    if (difference == 1) {
      return 'Yesterday';
    } else if (difference > 1) {
      return '$difference days ago';
    } else if (difference == -1) {
      return 'Tomorrow';
    } else {
      return '${-difference} days from now';
    }
  }
}
