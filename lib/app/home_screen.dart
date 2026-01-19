import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/clients/presentation/screens/client_home_screen.dart';
import '../features/trainer/presentation/screens/trainer_home_screen.dart';

/// Single home screen that displays trainer or client content based on role STATE.
/// No navigation occurs when switching roles - just a rebuild.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);

    // Show appropriate home based on role
    if (role.isTrainer) {
      return const TrainerHomeScreen();
    }
    return const ClientHomeScreen();
  }
}
