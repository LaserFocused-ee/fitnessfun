import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/failures.dart';
import '../../domain/entities/trainer_video.dart';
import '../../domain/repositories/video_library_repository.dart';

class SupabaseVideoLibraryRepository implements VideoLibraryRepository {
  SupabaseVideoLibraryRepository(this._client);

  final SupabaseClient _client;
  static const _bucketName = 'exercise-videos';
  static const _tableName = 'trainer_videos';

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<Either<Failure, List<TrainerVideo>>> getTrainerVideos({
    String? searchQuery,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return left(const AuthFailure(message: 'User not authenticated'));
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('trainer_id', userId)
          .order('created_at', ascending: false);

      List<TrainerVideo> videos = (response as List)
          .map((json) => _fromJson(json as Map<String, dynamic>))
          .toList();

      // Apply search filter client-side for flexibility
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        videos = videos.where((v) {
          return v.name.toLowerCase().contains(lowerQuery);
        }).toList();
      }

      return right(videos);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load videos: $e'));
    }
  }

  @override
  Future<Either<Failure, TrainerVideo>> getVideoById(String id) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .single();

      return right(_fromJson(response));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load video: $e'));
    }
  }

  @override
  Future<Either<Failure, TrainerVideo>> uploadVideo({
    required String filePath,
    required String name,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return left(const AuthFailure(message: 'User not authenticated'));
      }

      // Generate unique storage path
      final uuid = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(filePath).toLowerCase();
      final storagePath = '$userId/${uuid}_$timestamp$extension';

      // Get file size
      int? fileSize;
      if (!kIsWeb) {
        final file = File(filePath);
        fileSize = await file.length();
      }

      // Upload to Supabase Storage
      if (kIsWeb) {
        // Web upload using XFile
        await _client.storage.from(_bucketName).upload(
              storagePath,
              File(filePath),
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      } else {
        // Mobile upload with file
        final file = File(filePath);
        await _client.storage.from(_bucketName).upload(
              storagePath,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      }

      // Report progress complete (Supabase doesn't provide progress callbacks)
      onProgress?.call(1.0);

      // Create database record
      final data = {
        'trainer_id': userId,
        'name': name,
        'storage_path': storagePath,
        'file_size_bytes': fileSize,
      };

      final response = await _client
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      return right(_fromJson(response));
    } on StorageException catch (e) {
      return left(StorageFailure(message: 'Upload failed: ${e.message}'));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to upload video: $e'));
    }
  }

  @override
  Future<Either<Failure, TrainerVideo>> updateVideo({
    required String id,
    required String name,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return left(const AuthFailure(message: 'User not authenticated'));
      }

      final response = await _client
          .from(_tableName)
          .update({'name': name})
          .eq('id', id)
          .eq('trainer_id', userId) // Can only update own videos
          .select()
          .single();

      return right(_fromJson(response));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update video: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteVideo(String id) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return left(const AuthFailure(message: 'User not authenticated'));
      }

      // First get the video to get storage path
      final video = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .eq('trainer_id', userId)
          .single();

      final storagePath = video['storage_path'] as String;

      // Delete from storage
      await _client.storage.from(_bucketName).remove([storagePath]);

      // Delete from database
      await _client
          .from(_tableName)
          .delete()
          .eq('id', id)
          .eq('trainer_id', userId);

      return right(unit);
    } on StorageException catch (e) {
      return left(StorageFailure(message: 'Delete failed: ${e.message}'));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to delete video: $e'));
    }
  }

  @override
  String getPublicUrl(String storagePath) {
    return _client.storage.from(_bucketName).getPublicUrl(storagePath);
  }

  /// Convert database JSON to TrainerVideo entity
  TrainerVideo _fromJson(Map<String, dynamic> json) {
    // Convert snake_case to camelCase
    final result = json.map((key, value) {
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      return MapEntry(camelKey, value);
    });

    // Add video URL from storage path
    if (result['storagePath'] != null) {
      result['videoUrl'] = getPublicUrl(result['storagePath'] as String);
    }

    return TrainerVideo.fromJson(result);
  }
}
