/// Centralized route constants for the app.
///
/// Using constants prevents typos and makes refactoring easier.
abstract final class AppRoutes {
  // Auth routes
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String roleSelection = '/role-selection';

  // Client routes
  static const String clientHome = '/client';
  static const String checkin = '/client/checkin';
  static const String checkinHistory = '/client/checkin/history';
  static const String myPlans = '/client/plans';
  static const String workoutSession = '/client/plans/:planId/workout';
  static const String workoutHistory = '/client/workout-history';

  // Trainer routes
  static const String trainerHome = '/trainer';
  static const String clientList = '/trainer/clients';
  static const String clientDetail = '/trainer/clients/:clientId';
  static const String exerciseLibrary = '/trainer/exercises';
  static const String createExercise = '/trainer/exercises/create';
  static const String planBuilder = '/trainer/plans/create';
  static const String editPlan = '/trainer/plans/:planId';
}
