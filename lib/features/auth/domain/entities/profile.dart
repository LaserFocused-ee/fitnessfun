import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// User profile entity.
@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    required String email,
    required String role,
    String? fullName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

/// User role enum.
enum UserRole {
  trainer,
  client;

  /// Check if user is a trainer.
  bool get isTrainer => this == UserRole.trainer;

  /// Check if user is a client.
  bool get isClient => this == UserRole.client;
}
