import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../workout/domain/entities/workout_plan.dart';
import '../../../workout/presentation/providers/workout_provider.dart';

/// Section header for checkin form.
class CheckinSectionHeader extends StatelessWidget {
  const CheckinSectionHeader({super.key, required this.title});
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

/// Number field for decimal values (e.g., bodyweight).
class CheckinNumberField extends StatelessWidget {
  const CheckinNumberField({
    super.key,
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

/// Integer field for whole numbers (e.g., steps).
class CheckinIntField extends StatelessWidget {
  const CheckinIntField({
    super.key,
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

/// Text field for string values (e.g., notes).
class CheckinTextField extends StatelessWidget {
  const CheckinTextField({
    super.key,
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

/// Sleep duration picker with hours and minutes sliders.
class SleepDurationField extends StatelessWidget {
  const SleepDurationField({
    super.key,
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

/// Dropdown to select from assigned workout plans (stores plan ID).
class WorkoutPlanDropdown extends ConsumerWidget {
  const WorkoutPlanDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(clientPlansProvider);

    return plansAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.fitness_center_outlined),
              SizedBox(width: 12),
              Text('Loading plans...'),
              Spacer(),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.fitness_center_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text('Error loading plans: $e')),
            ],
          ),
        ),
      ),
      data: (plans) {
        final activePlans = plans.where((p) => p.isActive).toList();

        // Build dropdown items using plan ID as value
        final items = <DropdownMenuItem<String>>[
          const DropdownMenuItem(
            value: '',
            child: Text('Rest Day / No Workout'),
          ),
          ...activePlans.map((plan) => DropdownMenuItem(
                value: plan.planId, // Store the plan ID
                child: Text(plan.planName ?? 'Unnamed Plan'),
              )),
        ];

        // Check if current value matches any plan ID or is empty
        final currentValue = value ?? '';
        final isKnownValue = currentValue.isEmpty ||
            activePlans.any((p) => p.planId == currentValue);

        // Find plan name for display if we have an unknown value
        String? displayHint;
        if (!isKnownValue && currentValue.isNotEmpty) {
          displayHint = 'Unknown plan';
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.fitness_center_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: isKnownValue ? currentValue : null,
                    decoration: const InputDecoration(
                      labelText: 'Workout Plan',
                      border: InputBorder.none,
                    ),
                    hint: Text(displayHint ?? 'Select workout'),
                    items: items,
                    onChanged: (v) {
                      if (v == '') {
                        onChanged(null);
                      } else {
                        onChanged(v);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
