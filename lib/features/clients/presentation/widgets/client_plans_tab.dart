import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../workout/domain/entities/workout_plan.dart';
import '../providers/client_detail_provider.dart';

/// Tab displaying a client's assigned workout plans for trainers.
class ClientPlansTab extends ConsumerWidget {
  const ClientPlansTab({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(clientAssignedPlansProvider(clientId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return plansAsync.when(
      data: (plans) {
        // Separate active and past plans
        final activePlans = plans.where((p) => p.isActive).toList();
        final pastPlans = plans.where((p) => !p.isActive).toList();

        return Stack(
          children: [
            if (plans.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No plans assigned',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Assign a workout plan to this client',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _createPlan(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Plan'),
                    ),
                  ],
                ),
              )
            else
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // Active plans section
                  if (activePlans.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Active Plan',
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    ...activePlans.map((plan) => _PlanCard(
                          plan: plan,
                          isActive: true,
                          clientId: clientId,
                        )),
                    if (pastPlans.isNotEmpty) const SizedBox(height: 24),
                  ],

                  // Past plans section (collapsed by default)
                  if (pastPlans.isNotEmpty)
                    _CollapsiblePastPlans(
                      plans: pastPlans,
                      clientId: clientId,
                    ),
                ],
              ),

            // FAB for creating new plan
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _createPlan(context),
                icon: const Icon(Icons.add),
                label: const Text('Create Plan'),
              ),
            ),
          ],
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
                  ref.invalidate(clientAssignedPlansProvider(clientId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _createPlan(BuildContext context) {
    // Navigate to plan builder with clientId to auto-assign on creation
    context.push('/plans/create?clientId=$clientId');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.color,
  });

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.plan,
    required this.isActive,
    required this.clientId,
  });

  final ClientPlan plan;
  final bool isActive;
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/plans/${plan.planId}?clientId=$clientId'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 20,
                  color: isActive ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.planName ?? 'Workout Plan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Dates
            if (plan.startDate != null || plan.endDate != null)
              Row(
                children: [
                  Icon(
                    Icons.date_range,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateRange(plan, dateFormat),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),

            if (plan.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Assigned: ${dateFormat.format(plan.createdAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],

            // Actions for active plans
            if (isActive) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _deactivatePlan(context, ref),
                    child: const Text('Deactivate'),
                  ),
                ],
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  String _formatDateRange(ClientPlan plan, DateFormat format) {
    if (plan.startDate != null && plan.endDate != null) {
      return '${format.format(plan.startDate!)} - ${format.format(plan.endDate!)}';
    } else if (plan.startDate != null) {
      return 'From ${format.format(plan.startDate!)}';
    } else if (plan.endDate != null) {
      return 'Until ${format.format(plan.endDate!)}';
    }
    return '';
  }

  Future<void> _deactivatePlan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Plan'),
        content: Text(
            'Are you sure you want to deactivate "${plan.planName}"? The client will no longer see this plan as their active workout.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && context.mounted) {
      final result = await ref
          .read(clientPlanAssignmentNotifierProvider.notifier)
          .deactivatePlan(clientPlanId: plan.id, clientId: clientId);

      if (context.mounted) {
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
              const SnackBar(content: Text('Plan deactivated')),
            );
          },
        );
      }
    }
  }
}

class _CollapsiblePastPlans extends StatefulWidget {
  const _CollapsiblePastPlans({
    required this.plans,
    required this.clientId,
  });

  final List<ClientPlan> plans;
  final String clientId;

  @override
  State<_CollapsiblePastPlans> createState() => _CollapsiblePastPlansState();
}

class _CollapsiblePastPlansState extends State<_CollapsiblePastPlans> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Past Plans',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.plans.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          ...widget.plans.map((plan) => _PlanCard(
                plan: plan,
                isActive: false,
                clientId: widget.clientId,
              )),
        ],
      ],
    );
  }
}
