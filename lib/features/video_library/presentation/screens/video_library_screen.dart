import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/error/failures.dart';
import '../../../workout/presentation/widgets/video_player_dialog.dart';
import '../providers/video_library_provider.dart';
import '../widgets/video_thumbnail_card.dart';

class VideoLibraryScreen extends ConsumerStatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  ConsumerState<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends ConsumerState<VideoLibraryScreen> {
  final _searchController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    // Read bytes on web (File doesn't work on web platform)
    Uint8List? bytes;
    if (kIsWeb) {
      bytes = await video.readAsBytes();
    }

    final result = await ref.read(videoUploadNotifierProvider.notifier).upload(
          filePath: video.path,
          name: name,
          bytes: bytes,
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
        (video) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video uploaded successfully')),
          );
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

  Future<void> _handleDelete(String videoId, String videoName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: Text('Are you sure you want to delete "$videoName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result =
        await ref.read(videoManagementNotifierProvider.notifier).delete(videoId);

    if (mounted) {
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: ${failure.displayMessage}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video deleted')),
          );
        },
      );
    }
  }

  Future<void> _handleRename(String videoId, String currentName) async {
    final newName = await _showNameDialog(initialName: currentName);

    if (newName == null || newName.isEmpty || newName == currentName || !mounted) {
      return;
    }

    final result = await ref
        .read(videoManagementNotifierProvider.notifier)
        .updateName(id: videoId, name: newName);

    if (mounted) {
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rename failed: ${failure.displayMessage}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video renamed')),
          );
        },
      );
    }
  }

  void _playVideo(String videoUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(
        title: title,
        videoUrl: videoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(trainerVideosProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Library'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search videos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Upload progress indicator
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(),
            ),

          // Video grid
          Expanded(
            child: videosAsync.when(
              data: (videos) {
                // Apply search filter
                final searchQuery = _searchController.text.toLowerCase();
                final filteredVideos = searchQuery.isEmpty
                    ? videos
                    : videos
                        .where(
                            (v) => v.name.toLowerCase().contains(searchQuery))
                        .toList();

                if (filteredVideos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          size: 64,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          videos.isEmpty
                              ? 'No videos yet'
                              : 'No videos match your search',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (videos.isEmpty)
                          Text(
                            'Tap + to upload your first video',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        if (searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Text('Clear search'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filteredVideos.length,
                  itemBuilder: (context, index) {
                    final video = filteredVideos[index];
                    return VideoThumbnailCard(
                      video: video,
                      onTap: () {
                        if (video.videoUrl != null) {
                          _playVideo(video.videoUrl!, video.name);
                        }
                      },
                      onDelete: () => _handleDelete(video.id, video.name),
                      onRename: () => _handleRename(video.id, video.name),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(trainerVideosProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadVideo,
        icon: const Icon(Icons.add),
        label: const Text('Upload'),
      ),
    );
  }
}
