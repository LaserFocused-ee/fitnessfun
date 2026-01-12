import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../shared/widgets/active_workout_timer_banner.dart';
import 'router.dart';

/// Root application widget.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FitnessFun',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        return _AppShell(child: child);
      },
    );
  }
}

/// App shell that wraps all screens with global overlays like the workout timer.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main content
        Expanded(child: child ?? const SizedBox.shrink()),

        // Global workout timer banner (shows when workout active)
        const ActiveWorkoutTimerBanner(),
      ],
    );
  }
}
