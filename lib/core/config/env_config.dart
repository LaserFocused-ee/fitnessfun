import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for the app.
///
/// Loads values from .env file.
/// Works on iOS, Android, and Web.
class EnvConfig {
  const EnvConfig._();

  /// Load environment variables from .env file.
  /// Call this in main() before runApp().
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  /// Supabase URL.
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? 'http://127.0.0.1:54361';
  }

  /// Supabase anonymous key.
  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }
}
