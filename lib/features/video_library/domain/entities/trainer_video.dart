import 'package:freezed_annotation/freezed_annotation.dart';

part 'trainer_video.freezed.dart';
part 'trainer_video.g.dart';

@freezed
class TrainerVideo with _$TrainerVideo {
  const factory TrainerVideo({
    required String id,
    required String trainerId,
    required String name,
    required String storagePath,
    int? fileSizeBytes,
    @Default(false) bool isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Computed field for playback URL (set by repository)
    String? videoUrl,
  }) = _TrainerVideo;

  factory TrainerVideo.fromJson(Map<String, dynamic> json) =>
      _$TrainerVideoFromJson(json);

  /// Empty factory for form initialization
  factory TrainerVideo.empty() => const TrainerVideo(
        id: '',
        trainerId: '',
        name: '',
        storagePath: '',
      );
}
