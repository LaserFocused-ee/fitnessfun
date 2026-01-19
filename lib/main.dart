import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'core/config/env_config.dart';
import 'core/config/supabase_config.dart';
import 'core/utils/oauth_callback_detector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs instead of hash-based (e.g., /trainer instead of /#/trainer)
  usePathUrlStrategy();

  // Make URL bar reflect imperative navigation (push/pop)
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // Capture OAuth callback state BEFORE Supabase init (Supabase clears URL fragment)
  OAuthCallbackDetector.captureOAuthCallback();

  // Load environment variables
  await EnvConfig.load();

  // Initialize Supabase
  await initializeSupabase();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
