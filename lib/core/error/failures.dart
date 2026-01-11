import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

/// Base failure class for all app failures.
///
/// Using sealed class with Freezed for exhaustive pattern matching.
@freezed
sealed class Failure with _$Failure {
  /// Server/API error from Supabase or external services.
  const factory Failure.server({
    required String message,
    String? code,
  }) = ServerFailure;

  /// Authentication error (login, signup, etc.).
  const factory Failure.auth({
    required String message,
    String? code,
  }) = AuthFailure;

  /// Network error (no connection, timeout, etc.).
  const factory Failure.network({
    @Default('No internet connection') String message,
  }) = NetworkFailure;

  /// Storage error (file upload/download, etc.).
  const factory Failure.storage({
    required String message,
  }) = StorageFailure;

  /// Validation error (form validation, etc.).
  const factory Failure.validation({
    required String message,
    Map<String, String>? fieldErrors,
  }) = ValidationFailure;

  /// Cache/local storage error.
  const factory Failure.cache({
    required String message,
  }) = CacheFailure;

  /// Unknown/unexpected error.
  const factory Failure.unknown({
    @Default('An unexpected error occurred') String message,
    Object? error,
  }) = UnknownFailure;
}

/// Extension to get a user-friendly message from any failure.
extension FailureMessage on Failure {
  /// Returns a user-friendly message for display.
  String get displayMessage => when(
        server: (message, _) => message,
        auth: (message, _) => message,
        network: (message) => message,
        storage: (message) => message,
        validation: (message, _) => message,
        cache: (message) => message,
        unknown: (message, _) => message,
      );
}
