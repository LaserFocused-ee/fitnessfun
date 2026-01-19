import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/utils/oauth_callback_detector.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/add_role_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/role_selection_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/checkin/presentation/screens/checkin_form_screen.dart';
import '../features/checkin/presentation/screens/checkin_history_screen.dart';
import '../features/clients/presentation/screens/client_detail_screen.dart';
import '../features/clients/presentation/screens/client_home_screen.dart';
import '../features/clients/presentation/screens/client_list_screen.dart';
import '../features/exercise/presentation/screens/exercise_detail_screen.dart';
import '../features/exercise/presentation/screens/exercise_form_screen.dart';
import '../features/exercise/presentation/screens/exercise_library_screen.dart';
import '../features/trainer/presentation/screens/trainer_home_screen.dart';
import '../features/video_library/presentation/screens/video_library_screen.dart';
import '../features/workout/presentation/screens/plan_builder_screen.dart';
import '../features/workout/presentation/screens/plan_detail_screen.dart';
import '../features/workout/presentation/screens/plan_list_screen.dart';
import '../features/workout/presentation/screens/workout_history_screen.dart';
import '../features/workout/presentation/screens/workout_session_screen.dart';
import 'custom_page_transitions.dart';
import 'home_screen.dart';
import 'routes.dart';

part 'router.g.dart';

/// Global navigator key for accessing navigator from anywhere.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Listenable that triggers router refresh when auth state changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentProfileProvider, (_, __) => notifyListeners());
  }
}

/// Provides the GoRouter instance.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);
  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final profileAsync = ref.read(currentProfileProvider);
      final isAuthLoading = authState.isLoading;
      final isProfileLoading = profileAsync.isLoading;
      final isLoggedIn = authState.valueOrNull != null;
      final profile = profileAsync.valueOrNull;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;
      final isRoleSelection = state.matchedLocation == AppRoutes.roleSelection;

      // Check if user needs to select their role (OAuth users without explicit role)
      bool needsRoleSelection() {
        return profile != null && profile.effectiveActiveRole == 'pending';
      }

      debugPrint('Router: path=${state.uri.path}, matchedLocation=${state.matchedLocation}, '
          'wasOAuthCallback=${OAuthCallbackDetector.wasOAuthCallback}, '
          'isAuthLoading=$isAuthLoading, isLoggedIn=$isLoggedIn, '
          'hasError=${authState.hasError}, isSplash=$isSplash');

      // If returning from OAuth callback, wait until auth resolves
      if (OAuthCallbackDetector.wasOAuthCallback) {
        if (isLoggedIn) {
          // OAuth succeeded, clear the flag and proceed
          debugPrint('Router: OAuth succeeded, clearing flag');
          OAuthCallbackDetector.clear();
        } else if (!isAuthLoading && authState.hasError) {
          // OAuth failed, clear the flag
          debugPrint('Router: OAuth failed, clearing flag');
          OAuthCallbackDetector.clear();
        } else {
          // Still processing, stay on splash
          debugPrint('Router: OAuth processing, staying on splash');
          return isSplash ? null : AppRoutes.splash;
        }
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
          // Check if user needs to select their role (OAuth users)
          if (needsRoleSelection()) {
            return AppRoutes.roleSelection;
          }
          return AppRoutes.home;
        }
        return null; // Stay on splash while profile loads
      }

      // If not logged in and not on auth route, redirect to login
      if (!isLoggedIn && !isAuthRoute && !isSplash) {
        return AppRoutes.login;
      }

      // If logged in and on auth route, redirect to home
      if (isLoggedIn && isAuthRoute && !isProfileLoading) {
        // Check if user needs to select their role (OAuth users)
        if (needsRoleSelection()) {
          return AppRoutes.roleSelection;
        }
        return AppRoutes.home;
      }

      // If user needs role selection but is not on that page, redirect them
      if (isLoggedIn && !isProfileLoading && needsRoleSelection() && !isRoleSelection) {
        return AppRoutes.roleSelection;
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
      GoRoute(
        path: AppRoutes.addRole,
        builder: (context, state) => const AddRoleScreen(),
      ),

      // Home - landing page that shows trainer/client content based on role STATE
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),

      // Client routes (root level)
      GoRoute(
        path: AppRoutes.checkin,
        pageBuilder: (context, state) => SlideTransitionPage(
          key: state.pageKey,
          child: const CheckinFormScreen(),
        ),
        routes: [
          GoRoute(
            path: 'history',
            pageBuilder: (context, state) => SlideTransitionPage(
              key: state.pageKey,
              child: const CheckinHistoryScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.workoutHistory,
        pageBuilder: (context, state) => SlideTransitionPage(
          key: state.pageKey,
          child: const WorkoutHistoryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.myPlans,
        pageBuilder: (context, state) => SlideTransitionPage(
          key: state.pageKey,
          child: const ClientHomeScreen(),
        ),
        routes: [
          GoRoute(
            path: ':planId',
            pageBuilder: (context, state) {
              final planId = state.pathParameters['planId']!;
              return SlideTransitionPage(
                key: state.pageKey,
                child: PlanDetailScreen(planId: planId, isClientView: true),
              );
            },
            routes: [
              GoRoute(
                path: 'workout',
                pageBuilder: (context, state) {
                  final planId = state.pathParameters['planId']!;
                  final clientPlanId = state.uri.queryParameters['clientPlanId'];
                  final sessionId = state.uri.queryParameters['sessionId'];
                  return SlideTransitionPage(
                    key: state.pageKey,
                    child: WorkoutSessionScreen(
                      planId: planId,
                      clientPlanId: clientPlanId,
                      sessionId: sessionId,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),

      // Trainer routes (root level)
      GoRoute(
        path: AppRoutes.videos,
        pageBuilder: (context, state) => SlideTransitionPage(
          key: state.pageKey,
          child: const VideoLibraryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.clients,
        pageBuilder: (context, state) => SlideTransitionPage(
          key: state.pageKey,
          child: const ClientListScreen(),
        ),
        routes: [
          GoRoute(
            path: ':clientId',
            pageBuilder: (context, state) {
              final clientId = state.pathParameters['clientId']!;
              return SlideTransitionPage(
                key: state.pageKey,
                child: ClientDetailScreen(clientId: clientId),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.exercises,
        pageBuilder: (context, state) => SlideTransitionPage(
          key: state.pageKey,
          child: const ExerciseLibraryScreen(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            pageBuilder: (context, state) => SlideTransitionPage(
              key: state.pageKey,
              child: const ExerciseFormScreen(),
            ),
          ),
          GoRoute(
            path: ':exerciseId',
            pageBuilder: (context, state) {
              final exerciseId = state.pathParameters['exerciseId']!;
              return SlideTransitionPage(
                key: state.pageKey,
                child: ExerciseDetailScreen(exerciseId: exerciseId),
              );
            },
            routes: [
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) {
                  final exerciseId = state.pathParameters['exerciseId']!;
                  return SlideTransitionPage(
                    key: state.pageKey,
                    child: ExerciseFormScreen(exerciseId: exerciseId),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.plans,
        pageBuilder: (context, state) => SlideTransitionPage(
          key: state.pageKey,
          child: const PlanListScreen(),
        ),
        routes: [
          GoRoute(
            path: 'create',
            pageBuilder: (context, state) {
              final clientId = state.uri.queryParameters['clientId']!;
              return SlideTransitionPage(
                key: state.pageKey,
                child: PlanBuilderScreen(clientId: clientId),
              );
            },
          ),
          GoRoute(
            path: ':planId',
            pageBuilder: (context, state) {
              final planId = state.pathParameters['planId']!;
              final clientId = state.uri.queryParameters['clientId'];
              return SlideTransitionPage(
                key: state.pageKey,
                child: PlanDetailScreen(planId: planId, clientId: clientId),
              );
            },
            routes: [
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) {
                  final planId = state.pathParameters['planId']!;
                  final clientId = state.uri.queryParameters['clientId']!;
                  return SlideTransitionPage(
                    key: state.pageKey,
                    child: PlanBuilderScreen(planId: planId, clientId: clientId),
                  );
                },
              ),
            ],
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
