import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// Google Sign-In instance for native OAuth on mobile.
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // iOS requires the iOS client ID since we don't have GoogleService-Info.plist
    clientId: !kIsWeb && Platform.isIOS
        ? '829122064513-bsteklpibo43s4sejbi154ndobi9267c.apps.googleusercontent.com'
        : null,
    // Android needs serverClientId (Web client ID) to get ID token for Supabase
    serverClientId: '829122064513-sj3im0g92ghlv58m8igljsnspbim075o.apps.googleusercontent.com',
  );

  GoTrueClient get _auth => _client.auth;

  /// Get the redirect URL based on platform.
  String get _redirectUrl {
    if (kIsWeb) {
      // For web, use the current origin so it works for localhost and production
      return '${Uri.base.origin}/';
    }
    // For mobile, use the app's deep link scheme
    if (Platform.isIOS) {
      return 'com.fitnessfun.fitness-fun://';
    }
    return 'com.fitnessfun.fitness_fun://';
  }

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
  Future<Either<Failure, User>> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: Use browser-based OAuth flow
        return _signInWithGoogleWeb();
      } else {
        // Mobile: Use native Google Sign-In for better UX
        return _signInWithGoogleNative();
      }
    } on AuthException catch (e) {
      return left(Failure.auth(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  /// Web-based Google OAuth using browser redirect.
  /// For web, this initiates OAuth and the page redirects to Google.
  /// When returning, the router handles the session from URL tokens.
  Future<Either<Failure, User>> _signInWithGoogleWeb() async {
    // signInWithOAuth returns true if OAuth was initiated successfully.
    // For redirect flow, the page will navigate away to Google.
    // Session is established when returning via URL tokens.
    final success = await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      authScreenLaunchMode: LaunchMode.platformDefault,
    );

    if (!success) {
      return left(
        const Failure.auth(message: 'Google sign-in was cancelled.'),
      );
    }

    // For popup mode, check if user is now logged in
    final user = currentUser;
    if (user != null) {
      return right(user);
    }

    // For redirect mode, the page will navigate away. Return a special
    // failure that the UI will ignore (no error message shown).
    return left(const Failure.auth(message: '', code: 'redirect_pending'));
  }

  /// Native Google Sign-In for mobile platforms (better UX).
  Future<Either<Failure, User>> _signInWithGoogleNative() async {
    // Trigger native Google Sign-In UI
    final googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      return left(
        const Failure.auth(message: 'Google sign-in was cancelled.'),
      );
    }

    // Get authentication tokens from Google
    final googleAuth = await googleUser.authentication;

    if (googleAuth.idToken == null) {
      return left(
        const Failure.auth(message: 'Failed to get Google credentials.'),
      );
    }

    // Sign in to Supabase using Google ID token
    // This handles both new users and account linking automatically
    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
    );

    if (response.user == null) {
      return left(
        const Failure.auth(message: 'Google sign-in failed. Please try again.'),
      );
    }

    return right(response.user!);
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
      print('getCurrentProfile: userId=$userId');
      if (userId == null) {
        return left(const Failure.auth(message: 'Not logged in.'));
      }

      // Fetch profile data
      print('getCurrentProfile: fetching profile...');
      final profileResponse = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      print('getCurrentProfile: profileResponse=$profileResponse');

      // Fetch user's roles using RPC function (bypasses RLS issues)
      print('getCurrentProfile: fetching user_roles via RPC for userId=$userId');
      final rolesResponse = await _client
          .rpc('get_user_roles', params: {'p_user_id': userId});
      print('getCurrentProfile: rolesResponse=$rolesResponse (length=${(rolesResponse as List).length})');

      // Extract role strings from the response
      final roles = (rolesResponse as List)
          .map((r) => r['role'] as String)
          .toList();
      print('getCurrentProfile: roles=$roles');

      // Combine profile data with roles
      final profileWithRoles = {
        ...profileResponse,
        'roles': roles,
      };
      print('getCurrentProfile: profileWithRoles=$profileWithRoles');

      return right(Profile.fromJson(profileWithRoles));
    } on PostgrestException catch (e) {
      print('getCurrentProfile: PostgrestException: ${e.message}');
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e, st) {
      print('getCurrentProfile: Exception: $e\n$st');
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, Profile>> updateProfile({
    String? fullName,
    String? avatarUrl,
    UserRole? role,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        return left(const Failure.auth(message: 'Not logged in.'));
      }

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (role != null) {
        updates['role'] = role.name;
        updates['active_role'] = role.name;
      }

      if (updates.isEmpty) {
        return getCurrentProfile();
      }

      // Update profile
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      // If role is being set, also add to user_roles table
      if (role != null && role != UserRole.pending) {
        await _client.from('user_roles').upsert({
          'user_id': userId,
          'role': role.name,
        }, onConflict: 'user_id, role');
      }

      return getCurrentProfile();
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

  @override
  Future<Either<Failure, Profile>> updateActiveRole(UserRole role) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        return left(const Failure.auth(message: 'Not logged in.'));
      }

      // Update active_role in profiles table
      await _client
          .from('profiles')
          .update({'active_role': role.name})
          .eq('id', userId);

      return getCurrentProfile();
    } on PostgrestException catch (e) {
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }

  @override
  Future<Either<Failure, Profile>> addRole(UserRole role) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        return left(const Failure.auth(message: 'Not logged in.'));
      }

      // Insert new role into user_roles table (upsert to avoid duplicates)
      await _client.from('user_roles').upsert({
        'user_id': userId,
        'role': role.name,
      }, onConflict: 'user_id, role');

      // Also update active_role to the new role
      await _client
          .from('profiles')
          .update({'active_role': role.name})
          .eq('id', userId);

      return getCurrentProfile();
    } on PostgrestException catch (e) {
      return left(Failure.server(message: e.message, code: e.code));
    } catch (e) {
      return left(Failure.unknown(error: e));
    }
  }
}
