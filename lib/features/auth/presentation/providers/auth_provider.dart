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
  return repo.authStateChanges;
}

/// Provides the current user's profile (null if not logged in).
@riverpod
Future<Profile?> currentProfile(CurrentProfileRef ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final user = ref.watch(authStateProvider).valueOrNull;

  if (user == null) return null;

  final result = await repo.getCurrentProfile();
  return result.fold(
    (failure) => null,
    (profile) => profile,
  );
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
}
