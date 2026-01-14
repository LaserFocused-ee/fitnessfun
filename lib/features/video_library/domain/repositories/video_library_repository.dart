import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/trainer_video.dart';

/// Repository interface for video library operations
abstract class VideoLibraryRepository {
  /// Get all videos for the current trainer
  Future<Either<Failure, List<TrainerVideo>>> getTrainerVideos({
    String? searchQuery,
  });

  /// Get a single video by ID
  Future<Either<Failure, TrainerVideo>> getVideoById(String id);

  /// Upload a video file and create metadata record
  /// [filePath] is the local file path to upload
  /// [name] is the display name for the video
  /// [onProgress] optional callback for upload progress (0.0 to 1.0)
  Future<Either<Failure, TrainerVideo>> uploadVideo({
    required String filePath,
    required String name,
    void Function(double progress)? onProgress,
  });

  /// Update video metadata (name only - can't change file)
  Future<Either<Failure, TrainerVideo>> updateVideo({
    required String id,
    required String name,
  });

  /// Delete video (removes from storage AND database)
  Future<Either<Failure, Unit>> deleteVideo(String id);

  /// Get public URL for a storage path
  String getPublicUrl(String storagePath);
}
