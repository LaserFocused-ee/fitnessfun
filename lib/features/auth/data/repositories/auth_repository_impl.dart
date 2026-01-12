import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/auth_repository.dart';

/// Supabase implementation of [AuthRepository].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client) {
    // Create a single broadcast stream for auth state changes
    _authStateStream = _auth.onAuthStateChange
        .map((event) => event.session?.user)
        .asBroadcastStream();
  }

  final SupabaseClient _client;
  late final Stream<User?> _authStateStream;

  GoTrueClient get _auth => _client.auth;

  @override
  Stream<User?> get authStateChanges => _authStateStream;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'https://fitness-fun.onrender.com/',
        data: {
          'full_name': fullName,
          'role': role.name,
        },
      );

      if (response.user == null) {
        return left(
          const Failure.auth(message: 'Sign up failed. Please try again.'),
        );
      }

      return right(response.user!);
    } on AuthException catch (e) {
      return left(Failure.auth(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, User>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return left(
          const Failure.auth(message: 'Invalid email or password.'),
        );
      }

      return right(response.user!);
    } on AuthException catch (e) {
      return left(Failure.auth(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _auth.signOut();
      return right(unit);
    } on AuthException catch (e) {
      return left(Failure.auth(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, Profile>> getCurrentProfile() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        return left(const Failure.auth(message: 'Not logged in.'));
      }

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return right(Profile.fromJson(response));
    } on PostgrestException catch (e) {
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, Profile>> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        return left(const Failure.auth(message: 'Not logged in.'));
      }

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) {
        return getCurrentProfile();
      }

      final response = await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return right(Profile.fromJson(response));
    } on PostgrestException catch (e) {
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://fitness-fun.onrender.com/',
      );
      return right(unit);
    } on AuthException catch (e) {
      return left(Failure.auth(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }
}
