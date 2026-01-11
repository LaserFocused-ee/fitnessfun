import 'package:freezed_annotation/freezed_annotation.dart';

part 'trainer_client.freezed.dart';
part 'trainer_client.g.dart';

/// Represents a trainer-client relationship
@freezed
class TrainerClient with _$TrainerClient {
  const factory TrainerClient({
    required String id,
    required String trainerId,
    required String clientId,
    @Default('pending') String status, // pending, active, inactive
    DateTime? createdAt,
    // Denormalized fields for display
    String? trainerName,
    String? trainerEmail,
    String? clientName,
    String? clientEmail,
  }) = _TrainerClient;

  factory TrainerClient.fromJson(Map<String, dynamic> json) =>
      _$TrainerClientFromJson(json);
}

/// Status values for trainer-client relationships
class TrainerClientStatus {
  static const String pending = 'pending';
  static const String active = 'active';
  static const String inactive = 'inactive';

  static const List<String> all = [pending, active, inactive];
}

/// Represents a client invitation from trainer
@freezed
class ClientInvitation with _$ClientInvitation {
  const factory ClientInvitation({
    required String email,
    String? message,
  }) = _ClientInvitation;

  factory ClientInvitation.fromJson(Map<String, dynamic> json) =>
      _$ClientInvitationFromJson(json);
}
