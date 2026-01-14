import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/trainer_video.dart';

class VideoThumbnailCard extends StatelessWidget {
  const VideoThumbnailCard({
    super.key,
    required this.video,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  final TrainerVideo video;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video thumbnail
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video preview or placeholder
                  if (video.videoUrl != null)
                    _VideoThumbnailPreview(videoUrl: video.videoUrl!)
                  else
                    Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.video_library,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  // Play icon overlay
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        size: 32,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  // More options button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => _showContextMenu(context),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            colorScheme.surface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Video info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (video.fileSizeBytes != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(video.fileSizeBytes),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: colorScheme.error),
              title: Text('Delete', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget that shows the first frame of a video as a thumbnail.
/// Lazily initializes the video player and pauses after loading.
class _VideoThumbnailPreview extends StatefulWidget {
  const _VideoThumbnailPreview({required this.videoUrl});

  final String videoUrl;

  @override
  State<_VideoThumbnailPreview> createState() => _VideoThumbnailPreviewState();
}

class _VideoThumbnailPreviewState extends State<_VideoThumbnailPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();

      // Pause and seek to start to show first frame
      await _controller!.setVolume(0);
      await _controller!.pause();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
      if (kDebugMode) {
        print('Failed to load video thumbnail: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_hasError) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.video_library,
          size: 48,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
