import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/role_selection_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/checkin/presentation/screens/checkin_form_screen.dart';
import '../features/checkin/presentation/screens/checkin_history_screen.dart';
import 'routes.dart';

part 'router.g.dart';

/// Global navigator key for accessing navigator from anywhere.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Provides the GoRouter instance.
@riverpod
GoRouter router(RouterRef ref) {
  final authState = ref.watch(authStateProvider);
  final profileAsync = ref.watch(currentProfileProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthLoading = authState.isLoading;
      final isProfileLoading = profileAsync.isLoading;
      final isLoggedIn = authState.valueOrNull != null;
      final profile = profileAsync.valueOrNull;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;

      // Helper to get home route based on role
      String getHomeRoute() {
        if (profile?.role == 'trainer') {
          return AppRoutes.trainerHome;
        }
        return AppRoutes.clientHome;
      }

      // Stay on splash while loading auth or profile
      if ((isAuthLoading || (isLoggedIn && isProfileLoading)) && isSplash) {
        return null;
      }

      // Once loaded, if on splash, redirect based on auth state
      if (!isAuthLoading && isSplash) {
        if (!isLoggedIn) {
          return AppRoutes.login;
        }
        // Wait for profile to load before redirecting
        if (!isProfileLoading) {
          return getHomeRoute();
        }
        return null; // Stay on splash while profile loads
      }

      // If not logged in and not on auth route, redirect to login
      if (!isLoggedIn && !isAuthRoute && !isSplash) {
        return AppRoutes.login;
      }

      // If logged in and on auth route, redirect to appropriate home
      if (isLoggedIn && isAuthRoute && !isProfileLoading) {
        return getHomeRoute();
      }

      return null;
    },
    routes: [
      // Splash/loading screen
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),

      // Client routes
      GoRoute(
        path: AppRoutes.clientHome,
        builder: (context, state) => const _PlaceholderScreen(title: 'Client Home'),
        routes: [
          GoRoute(
            path: 'checkin',
            builder: (context, state) => const CheckinFormScreen(),
          ),
          GoRoute(
            path: 'checkin/history',
            builder: (context, state) => const CheckinHistoryScreen(),
          ),
          GoRoute(
            path: 'plans',
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'My Plans'),
          ),
        ],
      ),

      // Trainer routes
      GoRoute(
        path: AppRoutes.trainerHome,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Trainer Home'),
        routes: [
          GoRoute(
            path: 'clients',
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Client List'),
          ),
          GoRoute(
            path: 'exercises',
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Exercise Library'),
          ),
          GoRoute(
            path: 'plans/create',
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Create Plan'),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );
}

/// Simple splash screen while checking auth state.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Placeholder screen for routes not yet implemented.
class _PlaceholderScreen extends ConsumerWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
      body: Center(
        child: Text(
          '$title\n(Coming Soon)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}

/// Error screen for navigation errors.
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (error != null)
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
