# FitnessFun - Project Instructions

## Project Overview
Fitness tracking app for trainers and clients. Flutter frontend with Supabase backend.

## Tech Stack
- **Frontend:** Flutter (iOS, Android, Web)
- **Backend:** Supabase (PostgreSQL + Auth + Storage)
- **State Management:** Riverpod 3 with `@riverpod` code generation
- **Architecture:** Feature-first Clean Architecture

## Critical Rules

### Supabase CLI
**ALWAYS use `npx supabase` instead of `supabase` directly.**

```bash
# Start local Supabase
npx supabase start

# Stop local Supabase
npx supabase stop

# Check status
npx supabase status
```

### Supabase Migrations - IMPORTANT
**ALWAYS follow these rules for database changes:**

1. **ALWAYS use `npx supabase migration new` to create migration files:**
   ```bash
   npx supabase migration new add_some_feature
   ```
   Then edit the generated file in `supabase/migrations/`

2. **ALWAYS apply migrations with `--local` flag:**
   ```bash
   npx supabase db push --local
   ```

3. **NEVER use `npx supabase db reset` unless explicitly told to by the user.**
   This destroys all data. Only use when specifically requested.

4. **For ad-hoc queries, use psql directly** (see Direct Database Access section below)

### Riverpod Providers
**ALWAYS use code generation with `@riverpod` annotation. NEVER use manual provider definitions.**

```dart
// GOOD: Code generation
@riverpod
AuthRepository authRepository(Ref ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
}

// BAD: Manual (don't do this)
final authRepositoryProvider = Provider<AuthRepository>((ref) => ...);
```

### Code Generation
After modifying models or providers:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Local Development

### Custom Ports (5436x series)
This project uses custom ports to avoid conflicts:

| Service      | Port  |
|--------------|-------|
| Flutter Web  | 54300 |
| API          | 54361 |
| DB           | 54362 |
| Studio       | 54363 |
| Inbucket     | 54364 |
| Storage      | 54365 |
| Auth         | 54366 |
| Realtime     | 54367 |

### Starting Development

**IMPORTANT:** Always use the `/flutter-auto-reload` skill when starting Flutter for hot reload setup guidance.

```bash
# 1. Start Supabase (in project root)
npx supabase start

# 2. Run Flutter app (ALWAYS use port 54300 for web)
flutter run -d chrome --web-port=54300      # Web (required for OAuth redirects)
flutter run -d ios                           # iOS Simulator
flutter run -d android                       # Android Emulator
```

**Note:** Port 54300 is required for web development because Supabase auth is configured with redirect URLs pointing to this port.

### Supabase Studio
After starting, access at: http://localhost:54363

## Direct Database Access (psql)

**For ad-hoc SQL queries, use psql directly.** Do NOT use `supabase db execute` - it doesn't exist.

```bash
# From project directory - run SQL directly
PGPASSWORD=postgres psql -h localhost -p 54362 -U postgres -d postgres -c "SELECT * FROM profiles LIMIT 5;"

# Interactive psql session
PGPASSWORD=postgres psql -h localhost -p 54362 -U postgres -d postgres

# Example: View all daily checkins
PGPASSWORD=postgres psql -h localhost -p 54362 -U postgres -d postgres -c "SELECT * FROM daily_checkins ORDER BY date DESC LIMIT 10;"

# Example: Delete test data
PGPASSWORD=postgres psql -h localhost -p 54362 -U postgres -d postgres -c "DELETE FROM daily_checkins WHERE client_id = 'test-id';"
```

**Connection details:**
- Host: `localhost`
- Port: `54362` (custom Supabase port)
- User: `postgres`
- Password: `postgres`
- Database: `postgres`

## Database Schema

### Core Tables
- `profiles` - User profiles with role (trainer/client)
- `trainer_clients` - Trainer-client relationships
- `exercises` - Exercise library with video URLs
- `workout_plans` - Workout plan templates
- `plan_exercises` - Exercises in a plan with sets/reps/tempo
- `client_plans` - Plans assigned to clients
- `workout_sessions` - Completed workout logs
- `exercise_logs` - Individual exercise logs
- `daily_checkins` - Daily check-in data (biometrics, recovery, sleep)

### Migrations
Located in `supabase/migrations/`

**Create new migration:**
```bash
npx supabase migration new migration_name
```

**Apply migrations (always use --local):**
```bash
npx supabase db push --local
```

**Reset database (ONLY when explicitly requested by user):**
```bash
npx supabase db reset
```

## Project Structure

```
lib/
├── main.dart
├── app/                    # Router, app config
├── core/                   # Config, errors, theme
├── shared/                 # Reusable widgets
└── features/
    ├── auth/              # Authentication
    ├── checkin/           # Daily check-ins
    ├── exercise/          # Exercise library
    └── workout/           # Workout plans
```

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Building

```bash
# Web
flutter build web

# iOS
flutter build ios

# Android
flutter build apk
```

## Environment Variables

The app uses a single `.env` file (gitignored) loaded via `flutter_dotenv`.

**Setup:**
1. Copy `.env.example` to `.env`
2. Run `npx supabase status` to get the keys
3. Update `.env` with the values

```bash
# .env file format
SUPABASE_URL=http://127.0.0.1:54361
SUPABASE_ANON_KEY=<Publishable key from npx supabase status>
```

**Note:** The `.env` file is gitignored. Each developer creates their own from `.env.example`.
For production, update with actual Supabase project credentials.
