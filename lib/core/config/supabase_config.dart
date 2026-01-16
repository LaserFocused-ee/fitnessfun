import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env_config.dart';

part 'supabase_config.g.dart';

/// Provides the Supabase client instance.
///
/// This is a keepAlive provider since we need the client
/// throughout the app lifecycle.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(SupabaseClientRef ref) {
  return Supabase.instance.client;
}

/// Initializes Supabase with the configured URL and key.
///
/// Call this in main() before runApp().
/// Note: supabase_flutter automatically detects and handles OAuth callbacks
/// (PKCE code exchange) during initialization.
Future<void> initializeSupabase() async {
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );
}
