import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// User profile entity.
@freezed
class Profile with _$Profile {
  const Profile._();

  const factory Profile({
    required String id,
    required String email,
    required String role,
    @JsonKey(name: 'active_role') String? activeRole,
    @Default([]) List<String> roles,
    @JsonKey(name: 'full_name') String? fullName,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  /// Check if user has trainer role.
  bool get hasTrainerRole => roles.contains('trainer');

  /// Check if user has client role.
  bool get hasClientRole => roles.contains('client');

  /// Check if user can switch between roles.
  bool get canSwitchRoles => hasTrainerRole && hasClientRole;

  /// Get the effective active role (fallback to legacy role field).
  String get effectiveActiveRole => activeRole ?? role;
}

/// User role enum.
enum UserRole {
  trainer,
  client,
  pending;

  /// Check if user is a trainer.
  bool get isTrainer => this == UserRole.trainer;

  /// Check if user is a client.
  bool get isClient => this == UserRole.client;

  /// Check if role is pending selection.
  bool get isPending => this == UserRole.pending;

  /// Create from string value.
  static UserRole fromString(String value) {
    switch (value) {
      case 'trainer':
        return UserRole.trainer;
      case 'client':
        return UserRole.client;
      default:
        return UserRole.pending;
    }
  }
}
