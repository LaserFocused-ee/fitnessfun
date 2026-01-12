import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../workout/domain/entities/workout_session.dart';
import '../../../workout/presentation/providers/workout_provider.dart';
import '../providers/client_provider.dart';

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final trainerAsync = ref.watch(clientTrainerProvider);
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    final plansAsync = ref.watch(clientPlansProvider);
    final activeWorkout = ref.watch(activeWorkoutNotifierProvider).valueOrNull;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Fitness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            Text(
              'Welcome${profile?.fullName != null ? ', ${profile!.fullName}' : ''}!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Active workout banner
            if (activeWorkout != null)
              _ActiveWorkoutBanner(
                workout: activeWorkout,
                onContinue: () => context.push(
                    '/client/plans/${activeWorkout.planId}/workout?sessionId=${activeWorkout.id}'),
              ),

            // Pending invitations
            invitationsAsync.when(
              data: (invitations) {
                if (invitations.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      title: 'Pending Invitations',
                      icon: Icons.mail_outline,
                      color: colorScheme.tertiary,
                    ),
                    const SizedBox(height: 8),
                    ...invitations.map((inv) => _InvitationCard(
                          trainerName: inv.trainerName ?? 'Unknown Trainer',
                          trainerEmail: inv.trainerEmail ?? '',
                          onAccept: () => _acceptInvitation(context, ref, inv.id),
                          onDecline: () =>
                              _declineInvitation(context, ref, inv.id),
                        )),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // My Trainer section
            _SectionTitle(
              title: 'My Trainer',
              icon: Icons.person,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            trainerAsync.when(
              data: (trainer) {
                if (trainer == null) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 48,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No trainer linked yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ask your trainer to send you an invitation',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(trainer.trainerName ?? 'Your Trainer'),
                    subtitle: Text(trainer.trainerEmail ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $e'),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            _SectionTitle(
              title: 'Quick Actions',
              icon: Icons.flash_on,
              color: colorScheme.secondary,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.edit_note,
                    title: 'Daily Check-in',
                    color: colorScheme.primaryContainer,
                    onTap: () => context.push('/client/checkin'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.history,
                    title: 'Check-in History',
                    color: colorScheme.secondaryContainer,
                    onTap: () => context.push('/client/checkin/history'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.fitness_center,
                    title: 'Workout History',
                    color: colorScheme.tertiaryContainer,
                    onTap: () => context.push('/client/workout-history'),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),

            const SizedBox(height: 24),

            // My Plans section
            _SectionTitle(
              title: 'My Workout Plans',
              icon: Icons.fitness_center,
              color: colorScheme.tertiary,
            ),
            const SizedBox(height: 8),
            plansAsync.when(
              data: (plans) {
                final activePlans = plans.where((p) => p.isActive).toList();

                if (activePlans.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 48,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No workout plans assigned',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your trainer will assign plans to you',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: activePlans
                      .map((plan) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            colorScheme.tertiaryContainer,
                                        child: Icon(
                                          Icons.assignment,
                                          color: colorScheme.onTertiaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              plan.planName ?? 'Workout Plan',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (plan.startDate != null)
                                              Text(
                                                'Started ${_formatDate(plan.startDate!)}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => context.push(
                                              '/client/plans/${plan.planId}'),
                                          icon: const Icon(Icons.visibility,
                                              size: 18),
                                          label: const Text('View'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () => context.push(
                                              '/client/plans/${plan.planId}/workout?clientPlanId=${plan.id}'),
                                          icon: const Icon(Icons.play_arrow,
                                              size: 18),
                                          label: const Text('Start'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $e'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _acceptInvitation(
    BuildContext context,
    WidgetRef ref,
    String relationshipId,
  ) async {
    final result =
        await ref.read(invitationNotifierProvider.notifier).accept(relationshipId);

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
        (trainer) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You are now linked to ${trainer.trainerName}'),
            ),
          );
        },
      );
    }
  }

  Future<void> _declineInvitation(
    BuildContext context,
    WidgetRef ref,
    String relationshipId,
  ) async {
    final result =
        await ref.read(invitationNotifierProvider.notifier).decline(relationshipId);

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
            const SnackBar(content: Text('Invitation declined')),
          );
        },
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: colorScheme.onSurface),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.trainerName,
    required this.trainerEmail,
    required this.onAccept,
    required this.onDecline,
  });

  final String trainerName;
  final String trainerEmail;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.tertiaryContainer,
                  child: Icon(
                    Icons.person,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainerName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        trainerEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveWorkoutBanner extends StatelessWidget {
  const _ActiveWorkoutBanner({
    required this.workout,
    required this.onContinue,
  });

  final WorkoutSession workout;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final elapsed = workout.startedAt != null
        ? DateTime.now().difference(workout.startedAt!)
        : Duration.zero;

    final completedCount = workout.exerciseLogs.where((l) => l.completed).length;
    final totalCount = workout.exerciseLogs.length;

    return Card(
      color: colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: onContinue,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Workout in Progress',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatDuration(elapsed),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                workout.planName ?? 'Workout',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$completedCount of $totalCount exercises completed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continue Workout'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.onPrimaryContainer,
                    foregroundColor: colorScheme.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
