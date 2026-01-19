import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';

class SupabaseExerciseRepository implements ExerciseRepository {
  SupabaseExerciseRepository(this._client);

  final SupabaseClient _client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<Either<Failure, List<Exercise>>> getExercises({
    String? muscleGroup,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('exercises').select();

      // Filter by muscle group if provided
      if (muscleGroup != null && muscleGroup.isNotEmpty) {
        query = query.eq('muscle_group', muscleGroup);
      }

      // Filter: global OR created by current user
      if (_currentUserId != null) {
        query = query.or('is_global.eq.true,created_by.eq.$_currentUserId');
      } else {
        query = query.eq('is_global', true);
      }

      final response = await query.order('name', ascending: true);

      List<Exercise> exercises = (response as List)
          .map((json) => Exercise.fromJson(
              _snakeToCamel(json as Map<String, dynamic>)))
          .toList();

      // Apply search filter client-side for flexibility
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        exercises = exercises.where((e) {
          return e.name.toLowerCase().contains(lowerQuery) ||
              (e.muscleGroup?.toLowerCase().contains(lowerQuery) ?? false) ||
              (e.instructions?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }

      return right(exercises);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load exercises: $e'));
    }
  }

  @override
  Future<Either<Failure, Exercise>> getExerciseById(String id) async {
    try {
      final response = await _client
          .from('exercises')
          .select()
          .eq('id', id)
          .single();

      return right(Exercise.fromJson(_snakeToCamel(response)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load exercise: $e'));
    }
  }

  @override
  Future<Either<Failure, Exercise>> createExercise(Exercise exercise) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return left(const AuthFailure(message: 'User not authenticated'));
      }

      final data = _camelToSnake({
        'name': exercise.name,
        'instructions': exercise.instructions,
        'video_path': exercise.videoPath,
        'muscle_group': exercise.muscleGroup,
        'tempo': exercise.tempo,
        'created_by': userId,
        'is_global': false, // Trainer-created exercises are not global
      });

      final response = await _client
          .from('exercises')
          .insert(data)
          .select()
          .single();

      return right(Exercise.fromJson(_snakeToCamel(response)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to create exercise: $e'));
    }
  }

  @override
  Future<Either<Failure, Exercise>> updateExercise(Exercise exercise) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return left(const AuthFailure(message: 'User not authenticated'));
      }

      final data = _camelToSnake({
        'name': exercise.name,
        'instructions': exercise.instructions,
        'video_path': exercise.videoPath,
        'muscle_group': exercise.muscleGroup,
        'tempo': exercise.tempo,
      });

      final response = await _client
          .from('exercises')
          .update(data)
          .eq('id', exercise.id)
          .eq('created_by', userId) // Can only update own exercises
          .select()
          .single();

      return right(Exercise.fromJson(_snakeToCamel(response)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update exercise: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteExercise(String id) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return left(const AuthFailure(message: 'User not authenticated'));
      }

      await _client
          .from('exercises')
          .delete()
          .eq('id', id)
          .eq('created_by', userId); // Can only delete own exercises

      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to delete exercise: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Exercise>>> getExercisesByTrainer(
      String trainerId) async {
    try {
      final response = await _client
          .from('exercises')
          .select()
          .eq('created_by', trainerId)
          .order('name', ascending: true);

      final exercises = (response as List)
          .map((json) => Exercise.fromJson(
              _snakeToCamel(json as Map<String, dynamic>)))
          .toList();

      return right(exercises);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load trainer exercises: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Exercise>>> getGlobalExercises() async {
    try {
      final response = await _client
          .from('exercises')
          .select()
          .eq('is_global', true)
          .order('name', ascending: true);

      final exercises = (response as List)
          .map((json) => Exercise.fromJson(
              _snakeToCamel(json as Map<String, dynamic>)))
          .toList();

      return right(exercises);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load global exercises: $e'));
    }
  }

  /// Convert snake_case keys to camelCase for Dart models
  /// Also converts video_path to full storage URL
  Map<String, dynamic> _snakeToCamel(Map<String, dynamic> json) {
    final result = json.map((key, value) {
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      return MapEntry(camelKey, value);
    });

    // Convert video_path to full storage URL (keep videoPath for form editing)
    if (result['videoPath'] != null && result['videoPath'].toString().isNotEmpty) {
      final videoPath = result['videoPath'] as String;
      // Generate public URL for video playback
      result['videoUrl'] = _client.storage
          .from('exercise-videos')
          .getPublicUrl(videoPath);
      // Keep videoPath for form editing
    }

    return result;
  }

  /// Convert camelCase keys to snake_case for Supabase
  Map<String, dynamic> _camelToSnake(Map<String, dynamic> json) {
    return json.map((key, value) {
      final snakeKey = key.replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)!.toLowerCase()}',
      );
      return MapEntry(snakeKey, value);
    });
  }
}
