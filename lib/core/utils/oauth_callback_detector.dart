import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Detects if the app is returning from an OAuth callback.
/// Must be called BEFORE Supabase initialization since Supabase clears the URL fragment.
class OAuthCallbackDetector {
  OAuthCallbackDetector._();

  static bool _wasOAuthCallback = false;

  /// Whether we detected an OAuth callback on app startup.
  /// This is captured once at startup and doesn't change.
  static bool get wasOAuthCallback => _wasOAuthCallback;

  /// Check for OAuth callback tokens in URL.
  /// Call this BEFORE Supabase.initialize() since Supabase clears the URL.
  static void captureOAuthCallback() {
    if (!kIsWeb) return;

    // On web, check for OAuth tokens/codes in URL
    // Can be in fragment (#access_token=...) for implicit flow
    // Or in query string (?code=...) for PKCE flow
    final uri = Uri.base;
    final fragment = uri.fragment;
    final queryParams = uri.queryParameters;

    debugPrint('OAuthCallbackDetector: URL = ${uri.toString()}');
    debugPrint('OAuthCallbackDetector: fragment = $fragment');
    debugPrint('OAuthCallbackDetector: queryParams = $queryParams');

    _wasOAuthCallback = fragment.contains('access_token') ||
        fragment.contains('error=') ||
        queryParams.containsKey('code') ||
        queryParams.containsKey('error');

    debugPrint('OAuthCallbackDetector: wasOAuthCallback = $_wasOAuthCallback');
  }

  /// Clear the OAuth callback flag once auth has resolved.
  static void clear() {
    debugPrint('OAuthCallbackDetector: clearing flag');
    _wasOAuthCallback = false;
  }
}
