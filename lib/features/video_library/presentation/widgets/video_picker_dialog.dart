import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/trainer_video.dart';
import '../providers/video_library_provider.dart';

/// A dialog for selecting a video from the trainer's library or uploading a new one.
/// Returns the selected TrainerVideo or null if canceled.
class VideoPickerDialog extends ConsumerStatefulWidget {
  const VideoPickerDialog({
    super.key,
    this.selectedVideoPath,
  });

  /// The currently selected video storage path (for highlighting)
  final String? selectedVideoPath;

  @override
  ConsumerState<VideoPickerDialog> createState() => _VideoPickerDialogState();
}

class _VideoPickerDialogState extends ConsumerState<VideoPickerDialog> {
  String? _selectedPath;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedPath = widget.selectedVideoPath;
  }

  Future<void> _pickAndUploadVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null || !mounted) return;

    // Show name dialog
    final name = await _showNameDialog(
      initialName: video.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
    );

    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _isUploading = true);

    final result = await ref.read(videoUploadNotifierProvider.notifier).upload(
          filePath: video.path,
          name: name,
        );

    if (mounted) {
      setState(() => _isUploading = false);

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${failure.displayMessage}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
        (uploadedVideo) {
          // Auto-select the newly uploaded video and close
          Navigator.pop(context, uploadedVideo);
        },
      );
    }
  }

  Future<String?> _showNameDialog({String? initialName}) async {
    final controller = TextEditingController(text: initialName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter video name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(trainerVideosProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Video',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Upload button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickAndUploadVideo,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload),
                  label: Text(_isUploading ? 'Uploading...' : 'Upload New Video'),
                ),
              ),
            ),

            // Divider with "or select from library" text
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or select from library',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),

            // Video grid
            Expanded(
              child: videosAsync.when(
                data: (videos) {
                  if (videos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library_outlined,
                              size: 48,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No videos in your library',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a video to get started',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final video = videos[index];
                      final isSelected = video.storagePath == _selectedPath;

                      return _VideoGridItem(
                        video: video,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => _selectedPath = video.storagePath);
                        },
                        onDoubleTap: () {
                          Navigator.pop(context, video);
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error),
                      const SizedBox(height: 8),
                      Text('Error loading videos'),
                      TextButton(
                        onPressed: () => ref.invalidate(trainerVideosProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedPath != null
                        ? () {
                            final videos =
                                ref.read(trainerVideosProvider).valueOrNull;
                            final selected = videos?.firstWhere(
                              (v) => v.storagePath == _selectedPath,
                              orElse: () => TrainerVideo.empty(),
                            );
                            if (selected != null && selected.id.isNotEmpty) {
                              Navigator.pop(context, selected);
                            }
                          }
                        : null,
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoGridItem extends StatelessWidget {
  const _VideoGridItem({
    required this.video,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final TrainerVideo video;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video thumbnail or placeholder
            if (video.videoUrl != null)
              _MiniVideoThumbnail(videoUrl: video.videoUrl!)
            else
              Icon(
                Icons.video_library,
                size: 32,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            // Selection checkmark
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            // Video name
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  video.name,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini video thumbnail for picker grid items
class _MiniVideoThumbnail extends StatefulWidget {
  const _MiniVideoThumbnail({required this.videoUrl});

  final String videoUrl;

  @override
  State<_MiniVideoThumbnail> createState() => _MiniVideoThumbnailState();
}

class _MiniVideoThumbnailState extends State<_MiniVideoThumbnail> {
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

    if (_hasError || !_isInitialized || _controller == null) {
      return Icon(
        Icons.video_library,
        size: 32,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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

/// Helper function to show the video picker dialog
Future<TrainerVideo?> showVideoPickerDialog(
  BuildContext context, {
  String? selectedVideoPath,
}) {
  return showDialog<TrainerVideo>(
    context: context,
    builder: (context) => VideoPickerDialog(
      selectedVideoPath: selectedVideoPath,
    ),
  );
}
