import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/profile.dart';
import '../providers/auth_provider.dart';

/// Screen to add a new role (trainer or client) to the user's account.
class AddRoleScreen extends ConsumerStatefulWidget {
  const AddRoleScreen({super.key});

  @override
  ConsumerState<AddRoleScreen> createState() => _AddRoleScreenState();
}

class _AddRoleScreenState extends ConsumerState<AddRoleScreen> {
  bool _isLoading = false;

  Future<void> _addRole(UserRole role) async {
    setState(() => _isLoading = true);

    final success = await ref.read(roleSwitcherProvider.notifier).addRole(role);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      // Navigate to the appropriate home based on role
      if (role == UserRole.trainer) {
        context.go(AppRoutes.trainerHome);
      } else {
        context.go(AppRoutes.clientHome);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    // Listen for errors
    ref.listen(roleSwitcherProvider, (previous, next) {
      if (next.hasError && next.error is Failure) {
        final failure = next.error! as Failure;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.displayMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Role'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not logged in'));
          }

          // Determine which role the user can add
          final canAddTrainer = !profile.hasTrainerRole;
          final canAddClient = !profile.hasClientRole;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Expand Your Access',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add another role to switch between trainer and client views.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Show available role to add
                  if (canAddClient)
                    _RoleCard(
                      icon: Icons.person_outlined,
                      title: 'Add Client Role',
                      description:
                          'Track your own workouts, log daily check-ins, and follow a trainer\'s plans.',
                      isLoading: _isLoading,
                      onTap: _isLoading ? null : () => _addRole(UserRole.client),
                    ),
                  if (canAddClient && canAddTrainer) const SizedBox(height: 16),
                  if (canAddTrainer)
                    _RoleCard(
                      icon: Icons.sports_outlined,
                      title: 'Become a Trainer',
                      description:
                          'Create workout plans, manage clients, and track their progress.',
                      isLoading: _isLoading,
                      onTap: _isLoading ? null : () => _addRole(UserRole.trainer),
                    ),

                  // Show message if both roles already added
                  if (!canAddClient && !canAddTrainer)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'You have access to both roles!',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use the switch button in the app bar to change between trainer and client views.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
