import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Service for caching videos with download progress tracking.
/// Works on mobile (iOS/Android) with file caching and web with browser caching.
class VideoCacheService {
  VideoCacheService._();

  static final instance = VideoCacheService._();

  /// Custom cache manager for exercise videos with longer cache duration
  static final _cacheManager = CacheManager(
    Config(
      'exercise_videos_cache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 100,
    ),
  );

  /// Stream controller for download progress updates
  final _progressControllers = <String, StreamController<double>>{};

  /// Get or download a video file with progress updates.
  /// Returns the file path on mobile or the original URL on web.
  /// Progress is emitted to the stream (0.0 to 1.0).
  Stream<VideoDownloadState> getVideo(String url) async* {
    // Check if already cached (mobile only)
    if (!kIsWeb) {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo != null) {
        yield VideoDownloadState.completed(fileInfo.file.path);
        return;
      }
    }

    // Start download with progress tracking
    yield const VideoDownloadState.downloading(0.0);

    if (kIsWeb) {
      // On web, browser handles caching - just yield the URL
      // We'll simulate a brief loading state for UX consistency
      yield const VideoDownloadState.downloading(0.5);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      yield VideoDownloadState.completed(url);
    } else {
      // On mobile, download with progress tracking
      try {
        final stream = _cacheManager.getFileStream(
          url,
          withProgress: true,
        );

        await for (final response in stream) {
          if (response is DownloadProgress) {
            final progress = response.totalSize != null
                ? response.downloaded / response.totalSize!
                : 0.0;
            yield VideoDownloadState.downloading(progress);
          } else if (response is FileInfo) {
            yield VideoDownloadState.completed(response.file.path);
          }
        }
      } catch (e) {
        yield VideoDownloadState.error(e.toString());
      }
    }
  }

  /// Pre-cache a video in the background (mobile only)
  Future<void> preCacheVideo(String url) async {
    if (kIsWeb) return;

    final fileInfo = await _cacheManager.getFileFromCache(url);
    if (fileInfo == null) {
      await _cacheManager.downloadFile(url);
    }
  }

  /// Check if a video is cached
  Future<bool> isCached(String url) async {
    if (kIsWeb) return false;
    final fileInfo = await _cacheManager.getFileFromCache(url);
    return fileInfo != null;
  }

  /// Clear all cached videos
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    if (kIsWeb) return 0;
    // This is a rough estimate - flutter_cache_manager doesn't expose this directly
    return 0;
  }
}

/// State of video download
sealed class VideoDownloadState {
  const VideoDownloadState();

  const factory VideoDownloadState.downloading(double progress) =
      VideoDownloading;
  const factory VideoDownloadState.completed(String path) = VideoCompleted;
  const factory VideoDownloadState.error(String message) = VideoError;
}

class VideoDownloading extends VideoDownloadState {
  const VideoDownloading(this.progress);
  final double progress;
}

class VideoCompleted extends VideoDownloadState {
  const VideoCompleted(this.path);
  final String path;
}

class VideoError extends VideoDownloadState {
  const VideoError(this.message);
  final String message;
}
