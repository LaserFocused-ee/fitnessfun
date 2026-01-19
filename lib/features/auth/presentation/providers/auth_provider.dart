import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../../core/config/supabase_config.dart';
import '../../../../core/error/failures.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

/// Provides the auth repository instance.
@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
}

/// Provides the current auth state.
/// Uses Supabase's onAuthStateChange which emits initial state on subscribe.
@Riverpod(keepAlive: true)
Stream<User?> authState(AuthStateRef ref) {
  final repo = ref.watch(authRepositoryProvider);
  // Supabase's onAuthStateChange emits the current state immediately on subscribe
  // Invalidate profile on every auth state change to ensure fresh data
  return repo.authStateChanges.map((user) {
    // Invalidate profile to force re-fetch with fresh roles
    Future.microtask(() => ref.invalidate(currentProfileProvider));
    return user;
  });
}

/// Provides the current user's profile (null if not logged in).
@riverpod
Future<Profile?> currentProfile(CurrentProfileRef ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;

  print('currentProfile: authState.isLoading=${authState.isLoading}, '
      'hasError=${authState.hasError}, user=${user?.id}');

  if (user == null) return null;

  final result = await repo.getCurrentProfile();
  return result.fold(
    (failure) {
      print('currentProfile: FAILED to fetch profile: $failure');
      return null;
    },
    (profile) {
      print('currentProfile: Got profile for ${profile.email}, '
          'activeRole=${profile.activeRole}, roles=${profile.roles}');
      return profile;
    },
  );
}

/// Provides the current active role.
@riverpod
UserRole activeRole(ActiveRoleRef ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return UserRole.fromString(profile?.effectiveActiveRole ?? 'pending');
}

/// Notifier for handling auth actions (sign in, sign up, sign out).
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<void> build() {
    // Initial state is void
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Sign up a new user.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    state = const AsyncLoading();

    final result = await _repo.signUp(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
    );

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  /// Sign in an existing user.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    final result = await _repo.signIn(
      email: email,
      password: password,
    );

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  /// Sign out the current user.
  Future<bool> signOut() async {
    state = const AsyncLoading();

    final result = await _repo.signOut();

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  /// Sign in with Google OAuth.
  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();

    final result = await _repo.signInWithGoogle();

    return result.fold(
      (failure) {
        // For web redirect flow, don't show error - page is redirecting
        final isRedirectPending = failure is AuthFailure &&
            (failure as AuthFailure).code == 'redirect_pending';
        if (isRedirectPending) {
          return false;
        }
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  /// Update the current user's profile (including role).
  Future<bool> updateProfile({
    String? fullName,
    String? avatarUrl,
    UserRole? role,
  }) async {
    state = const AsyncLoading();

    final result = await _repo.updateProfile(
      fullName: fullName,
      avatarUrl: avatarUrl,
      role: role,
    );

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        // Set state FIRST before invalidating to avoid race condition
        state = const AsyncData(null);
        // Then invalidate the current profile to refetch it
        ref.invalidate(currentProfileProvider);
        return true;
      },
    );
  }
}

/// Notifier for role switching and adding new roles.
/// Note: This notifier deliberately does NOT use state (AsyncLoading/AsyncData)
/// because ref.invalidate() causes Riverpod state management conflicts.
@riverpod
class RoleSwitcher extends _$RoleSwitcher {
  @override
  FutureOr<void> build() {
    // No state needed - this is just an action handler
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Switch to a different active role.
  Future<bool> switchRole(UserRole newRole) async {
    try {
      final result = await _repo.updateActiveRole(newRole);

      return result.fold(
        (failure) {
          print('RoleSwitcher: switchRole failed: $failure');
          return false;
        },
        (_) {
          print('RoleSwitcher: switchRole succeeded, invalidating profile');
          // Invalidate the current profile to refetch with new role
          ref.invalidate(currentProfileProvider);
          return true;
        },
      );
    } catch (e) {
      print('RoleSwitcher: switchRole exception: $e');
      return false;
    }
  }

  /// Add a new role to the user's available roles.
  Future<bool> addRole(UserRole newRole) async {
    try {
      final result = await _repo.addRole(newRole);

      return result.fold(
        (failure) {
          print('RoleSwitcher: addRole failed: $failure');
          return false;
        },
        (_) {
          print('RoleSwitcher: addRole succeeded, invalidating profile');
          // Invalidate the current profile to refetch with new role
          ref.invalidate(currentProfileProvider);
          return true;
        },
      );
    } catch (e) {
      print('RoleSwitcher: addRole exception: $e');
      return false;
    }
  }
}
