import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../../core/error/failures.dart';
import '../entities/profile.dart';

/// Abstract repository for authentication operations.
///
/// This interface allows swapping implementations for testing or
/// using a different backend.
abstract class AuthRepository {
  /// Stream of auth state changes.
  Stream<User?> get authStateChanges;

  /// Get the current user (null if not logged in).
  User? get currentUser;

  /// Sign up with email and password.
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  });

  /// Sign in with email and password.
  Future<Either<Failure, User>> signIn({
    required String email,
    required String password,
  });

  /// Sign in with Google OAuth.
  ///
  /// If an account with the same email already exists (e.g., email/password),
  /// the Google identity will be linked to the existing account.
  Future<Either<Failure, User>> signInWithGoogle();

  /// Sign out the current user.
  Future<Either<Failure, Unit>> signOut();

  /// Get the current user's profile.
  Future<Either<Failure, Profile>> getCurrentProfile();

  /// Update the current user's profile.
  Future<Either<Failure, Profile>> updateProfile({
    String? fullName,
    String? avatarUrl,
  });

  /// Send password reset email.
  Future<Either<Failure, Unit>> resetPassword(String email);
}
