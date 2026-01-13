import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../shared/services/video_cache_service.dart';

/// Video player dialog that handles portrait/landscape videos appropriately.
/// Videos are muted by default to not interrupt music.
class VideoPlayerDialog extends StatefulWidget {
  const VideoPlayerDialog({
    super.key,
    required this.title,
    required this.videoUrl,
  });

  final String title;
  final String videoUrl;

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isDownloading = true;
  double _downloadProgress = 0.0;
  bool _isInitializing = false;
  String? _error;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _downloadAndPlay();
  }

  Future<void> _downloadAndPlay() async {
    final cacheService = VideoCacheService.instance;

    await for (final state in cacheService.getVideo(widget.videoUrl)) {
      if (!mounted) return;

      switch (state) {
        case VideoDownloading(progress: final progress):
          setState(() {
            _isDownloading = true;
            _downloadProgress = progress;
          });
        case VideoCompleted(path: final path):
          setState(() {
            _isDownloading = false;
            _isInitializing = true;
          });
          await _initializePlayer(path);
        case VideoError(message: final message):
          setState(() {
            _isDownloading = false;
            _error = message;
          });
      }
    }
  }

  Future<void> _initializePlayer(String videoPath) async {
    try {
      if (kIsWeb) {
        _videoController =
            VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else {
        _videoController = VideoPlayerController.file(File(videoPath));
      }

      await _videoController!.initialize();

      // Start muted by default
      await _videoController!.setVolume(0);

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        showControls: true,
        aspectRatio: _videoController!.value.aspectRatio,
      );

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = e.toString();
        });
      }
    }
  }

  void _toggleMute() {
    if (_videoController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    // Determine if video is portrait mode
    final videoAspect = _videoController?.value.aspectRatio ?? 16 / 9;
    final isPortrait = videoAspect < 1;

    // For portrait videos, use more vertical space
    final maxWidth =
        isPortrait ? screenSize.width * 0.95 : screenSize.width * 0.9;
    final maxHeight =
        isPortrait ? screenSize.height * 0.9 : screenSize.height * 0.8;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPortrait ? 8 : 16,
        vertical: isPortrait ? 24 : 16,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Mute/unmute button
                  if (_videoController != null && !_isInitializing)
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        size: 22,
                      ),
                      onPressed: _toggleMute,
                      tooltip: _isMuted ? 'Unmute' : 'Mute',
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: _buildVideoContent(colorScheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent(ColorScheme colorScheme) {
    if (_isDownloading) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  color: colorScheme.primary,
                ),
              ),
              if (_downloadProgress > 0) ...[
                const SizedBox(height: 16),
                Text(
                  '${(_downloadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_isInitializing) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load video',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: _chewieController != null
          ? Chewie(controller: _chewieController!)
          : const SizedBox.shrink(),
    );
  }
}
