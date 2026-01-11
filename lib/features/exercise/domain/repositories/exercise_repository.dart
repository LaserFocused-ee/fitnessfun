import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/exercise.dart';

/// Repository interface for exercise operations
abstract class ExerciseRepository {
  /// Get all exercises (global + trainer's own)
  Future<Either<Failure, List<Exercise>>> getExercises({
    String? muscleGroup,
    String? searchQuery,
  });

  /// Get a single exercise by ID
  Future<Either<Failure, Exercise>> getExerciseById(String id);

  /// Create a new exercise (trainer only)
  Future<Either<Failure, Exercise>> createExercise(Exercise exercise);

  /// Update an existing exercise (trainer only, own exercises)
  Future<Either<Failure, Exercise>> updateExercise(Exercise exercise);

  /// Delete an exercise (trainer only, own exercises)
  Future<Either<Failure, Unit>> deleteExercise(String id);

  /// Get exercises by trainer (for management)
  Future<Either<Failure, List<Exercise>>> getExercisesByTrainer(String trainerId);

  /// Get global exercises only
  Future<Either<Failure, List<Exercise>>> getGlobalExercises();
}
