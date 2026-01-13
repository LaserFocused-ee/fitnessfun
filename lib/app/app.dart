import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/workout/presentation/providers/workout_provider.dart';
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
/// Also handles restoring active workout sessions on startup.
class _AppShell extends ConsumerStatefulWidget {
  const _AppShell({required this.child});

  final Widget? child;

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  bool _hasRestoredSession = false;

  @override
  void initState() {
    super.initState();
    // Attempt to restore active session after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRestoreActiveSession();
    });
  }

  Future<void> _tryRestoreActiveSession() async {
    if (_hasRestoredSession) return;

    // Check if user is already logged in
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile != null) {
      _hasRestoredSession = true;
      await ref
          .read(activeWorkoutNotifierProvider.notifier)
          .checkAndRestoreActiveSession();
    } else {
      // Listen for auth changes and restore when logged in
      ref.listenManual(currentProfileProvider, (prev, next) {
        if (!_hasRestoredSession &&
            prev?.valueOrNull == null &&
            next.valueOrNull != null) {
          _hasRestoredSession = true;
          ref
              .read(activeWorkoutNotifierProvider.notifier)
              .checkAndRestoreActiveSession();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main content
        Expanded(child: widget.child ?? const SizedBox.shrink()),

        // Global workout timer banner (shows when workout active)
        const ActiveWorkoutTimerBanner(),
      ],
    );
  }
}
