import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:web/web.dart' as web;

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

  /// Clear the OAuth callback flag and clean up the URL.
  static void clear() {
    debugPrint('OAuthCallbackDetector: clearing flag');
    _wasOAuthCallback = false;
    _cleanupUrl();
  }

  /// Remove OAuth query parameters from the URL (web only).
  static void _cleanupUrl() {
    if (!kIsWeb) return;

    final uri = Uri.base;
    // Only clean up if there are OAuth-related query params
    if (uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error')) {
      // Build clean URL with just the fragment (hash route)
      final cleanUrl = '${uri.origin}/${uri.fragment.isNotEmpty ? '#${uri.fragment}' : ''}';
      debugPrint('OAuthCallbackDetector: cleaning URL to $cleanUrl');
      web.window.history.replaceState(null, '', cleanUrl);
    }
  }
}
