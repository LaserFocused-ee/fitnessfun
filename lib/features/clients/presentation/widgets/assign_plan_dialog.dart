import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../workout/domain/entities/workout_plan.dart';
import '../../../workout/presentation/providers/workout_provider.dart';
import '../providers/client_detail_provider.dart';

/// Dialog for assigning a workout plan to a client.
class AssignPlanDialog extends ConsumerStatefulWidget {
  const AssignPlanDialog({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  ConsumerState<AssignPlanDialog> createState() => _AssignPlanDialogState();
}

class _AssignPlanDialogState extends ConsumerState<AssignPlanDialog> {
  WorkoutPlan? _selectedPlan;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(trainerPlansProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MMM d, yyyy');

    return AlertDialog(
      title: const Text('Assign Workout Plan'),
      content: SizedBox(
        width: double.maxFinite,
        child: plansAsync.when(
          data: (plans) {
            if (plans.isEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center_outlined,
                    size: 48,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text('No plans available'),
                  const SizedBox(height: 8),
                  Text(
                    'Create a workout plan first',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan selection
                  Text(
                    'Select Plan',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<WorkoutPlan>(
                    value: _selectedPlan,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Choose a plan',
                    ),
                    items: plans
                        .map((plan) => DropdownMenuItem<WorkoutPlan>(
                              value: plan,
                              child: Text(plan.name),
                            ))
                        .toList(),
                    onChanged: (plan) {
                      setState(() => _selectedPlan = plan);
                    },
                  ),

                  if (_selectedPlan != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedPlan!.exercises.length} exercises',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Optional dates
                  Text(
                    'Schedule (Optional)',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Start date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_arrow),
                    title: const Text('Start Date'),
                    subtitle: Text(
                      _startDate != null
                          ? dateFormat.format(_startDate!)
                          : 'Not set',
                    ),
                    trailing: _startDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _startDate = null),
                          )
                        : null,
                    onTap: () => _selectDate(isStartDate: true),
                  ),

                  // End date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.stop),
                    title: const Text('End Date'),
                    subtitle: Text(
                      _endDate != null
                          ? dateFormat.format(_endDate!)
                          : 'Not set',
                    ),
                    trailing: _endDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _endDate = null),
                          )
                        : null,
                    onTap: () => _selectDate(isStartDate: false),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Note: Assigning a new plan will deactivate any current active plan.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              const SizedBox(height: 8),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading || _selectedPlan == null ? null : _assignPlan,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final initialDate = isStartDate
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());

    final firstDate = isStartDate
        ? DateTime.now().subtract(const Duration(days: 365))
        : (_startDate ?? DateTime.now().subtract(const Duration(days: 365)));

    final lastDate = DateTime.now().add(const Duration(days: 365 * 2));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selectedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = selectedDate;
          // Clear end date if it's before start date
          if (_endDate != null && _endDate!.isBefore(selectedDate)) {
            _endDate = null;
          }
        } else {
          _endDate = selectedDate;
        }
      });
    }
  }

  Future<void> _assignPlan() async {
    if (_selectedPlan == null) return;

    setState(() => _isLoading = true);

    final result = await ref
        .read(clientPlanAssignmentNotifierProvider.notifier)
        .assignPlan(
          planId: _selectedPlan!.id,
          clientId: widget.clientId,
          startDate: _startDate,
          endDate: _endDate,
        );

    setState(() => _isLoading = false);

    if (mounted) {
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.displayMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
        (clientPlan) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assigned "${_selectedPlan!.name}" to client'),
            ),
          );
        },
      );
    }
  }
}
