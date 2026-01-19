import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/video_library_repository_impl.dart';
import '../../domain/entities/trainer_video.dart';
import '../../domain/repositories/video_library_repository.dart';

part 'video_library_provider.g.dart';

/// Provides the VideoLibraryRepository instance
@riverpod
VideoLibraryRepository videoLibraryRepository(VideoLibraryRepositoryRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabaseVideoLibraryRepository(supabase);
}

/// Provides all videos for the current trainer
@riverpod
Future<List<TrainerVideo>> trainerVideos(TrainerVideosRef ref) async {
  final repo = ref.watch(videoLibraryRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (profile == null || profile.activeRole != 'trainer') {
    return [];
  }

  final result = await repo.getTrainerVideos();

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (videos) => videos,
  );
}

/// Provides filtered videos based on search query
@riverpod
Future<List<TrainerVideo>> filteredTrainerVideos(
  FilteredTrainerVideosRef ref, {
  String? searchQuery,
}) async {
  final repo = ref.watch(videoLibraryRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (profile == null || profile.activeRole != 'trainer') {
    return [];
  }

  final result = await repo.getTrainerVideos(searchQuery: searchQuery);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (videos) => videos,
  );
}

/// Get a single video by ID
@riverpod
Future<TrainerVideo> videoById(VideoByIdRef ref, String id) async {
  final repo = ref.watch(videoLibraryRepositoryProvider);
  final result = await repo.getVideoById(id);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (video) => video,
  );
}

/// Notifier for video upload operations
@riverpod
class VideoUploadNotifier extends _$VideoUploadNotifier {
  @override
  AsyncValue<TrainerVideo?> build() => const AsyncData(null);

  /// Upload a video file
  /// Returns the created TrainerVideo on success
  /// [bytes] is required for web uploads
  Future<Either<Failure, TrainerVideo>> upload({
    required String filePath,
    required String name,
    Uint8List? bytes,
    void Function(double progress)? onProgress,
  }) async {
    state = const AsyncLoading();

    final repo = ref.read(videoLibraryRepositoryProvider);

    final result = await repo.uploadVideo(
      filePath: filePath,
      name: name,
      bytes: bytes,
      onProgress: onProgress,
    );

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (video) => AsyncData(video),
    );

    // Refresh the video list on success
    if (result.isRight()) {
      ref.invalidate(trainerVideosProvider);
    }

    return result;
  }
}

/// Notifier for video management operations (update, delete)
@riverpod
class VideoManagementNotifier extends _$VideoManagementNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Update video name
  Future<Either<Failure, TrainerVideo>> updateName({
    required String id,
    required String name,
  }) async {
    state = const AsyncLoading();

    final repo = ref.read(videoLibraryRepositoryProvider);
    final result = await repo.updateVideo(id: id, name: name);

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    // Refresh the video list
    if (result.isRight()) {
      ref.invalidate(trainerVideosProvider);
    }

    return result;
  }

  /// Delete a video
  Future<Either<Failure, Unit>> delete(String id) async {
    state = const AsyncLoading();

    final repo = ref.read(videoLibraryRepositoryProvider);
    final result = await repo.deleteVideo(id);

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    // Refresh the video list
    if (result.isRight()) {
      ref.invalidate(trainerVideosProvider);
    }

    return result;
  }
}
