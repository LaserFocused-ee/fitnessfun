/// Centralized route constants for the app.
///
/// Using constants prevents typos and makes refactoring easier.
abstract final class AppRoutes {
  // Auth routes
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String roleSelection = '/role-selection';
  static const String addRole = '/add-role';

  // Home - landing page that shows trainer/client content based on role
  static const String home = '/home';

  // Client routes (root level)
  static const String checkin = '/checkin';
  static const String checkinHistory = '/checkin/history';
  static const String workoutHistory = '/workout-history';
  static const String myPlans = '/my-plans';
  static const String myPlanDetail = '/my-plans/:planId';
  static const String workoutSession = '/my-plans/:planId/workout';

  // Trainer routes (root level)
  static const String clients = '/clients';
  static const String clientDetail = '/clients/:clientId';
  static const String exercises = '/exercises';
  static const String exerciseDetail = '/exercises/:exerciseId';
  static const String createExercise = '/exercises/create';
  static const String editExercise = '/exercises/:exerciseId/edit';
  static const String plans = '/plans';
  static const String planDetail = '/plans/:planId';
  static const String createPlan = '/plans/create';
  static const String editPlan = '/plans/:planId/edit';
  static const String videos = '/videos';
}
