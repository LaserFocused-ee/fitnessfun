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
                      'Create workout plans for this client',
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
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: plans.length,
                itemBuilder: (context, index) => _PlanCard(
                  plan: plans[index],
                  clientId: clientId,
                ),
              ),

            // FAB for creating new plan
            if (plans.isNotEmpty)
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
    context.push('/plans/create?clientId=$clientId');
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.plan,
    required this.clientId,
  });

  final ClientPlan plan;
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/plans/${plan.planId}?clientId=$clientId'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.fitness_center,
                size: 24,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.planName ?? 'Workout Plan',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (plan.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Added ${dateFormat.format(plan.createdAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onSelected: (value) {
                  if (value == 'remove') {
                    _removePlan(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Remove from client'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removePlan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Plan'),
        content: Text(
          'Remove "${plan.planName}" from this client? They will no longer see this plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
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
              const SnackBar(content: Text('Plan removed')),
            );
          },
        );
      }
    }
  }
}
