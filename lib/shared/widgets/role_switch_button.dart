import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../features/auth/domain/entities/profile.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Button widget to switch between trainer and client roles.
/// Shows in app bar when user has both roles available.
class RoleSwitchButton extends ConsumerWidget {
  const RoleSwitchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null || !profile.canSwitchRoles) {
          return const SizedBox.shrink();
        }

        final currentRole = UserRole.fromString(profile.effectiveActiveRole);
        final targetRole = currentRole.isTrainer ? UserRole.client : UserRole.trainer;

        return IconButton(
          icon: Icon(
            targetRole.isTrainer ? Icons.fitness_center : Icons.people,
          ),
          tooltip: 'Switch to ${targetRole.name}',
          onPressed: () => _showSwitchDialog(context, ref, targetRole),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showSwitchDialog(BuildContext context, WidgetRef ref, UserRole targetRole) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to ${targetRole.name}?'),
        content: Text(
          targetRole.isTrainer
              ? 'You will see your trainer dashboard with clients and workout plans.'
              : 'You will see your client dashboard with your workouts and check-ins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if ((confirmed ?? false) && context.mounted) {
        // Just switch the role - router's redirect will handle navigation
        await ref.read(roleSwitcherProvider.notifier).switchRole(targetRole);
      }
    });
  }
}
