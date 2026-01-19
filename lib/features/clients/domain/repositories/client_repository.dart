import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/profile.dart';
import '../entities/trainer_client.dart';

/// Repository interface for trainer-client relationship operations
abstract class ClientRepository {
  // ===== For Trainers =====

  /// Get all clients for a trainer
  Future<Either<Failure, List<TrainerClient>>> getTrainerClients(
      String trainerId);

  /// Invite a client by email
  /// Creates a pending relationship if client exists, or sends invitation
  Future<Either<Failure, TrainerClient>> inviteClient({
    required String trainerId,
    required String clientEmail,
  });

  /// Remove a client from trainer's list
  Future<Either<Failure, Unit>> removeClient(String relationshipId);

  /// Get client profile details
  Future<Either<Failure, Profile>> getClientProfile(String clientId);

  // ===== For Clients =====

  /// Get the client's trainers (active relationships)
  Future<Either<Failure, List<TrainerClient>>> getClientTrainers(String clientId);

  /// Get pending invitations for a client
  Future<Either<Failure, List<TrainerClient>>> getPendingInvitations(
      String clientId);

  /// Accept a trainer invitation
  Future<Either<Failure, TrainerClient>> acceptInvitation(
      String relationshipId);

  /// Decline a trainer invitation
  Future<Either<Failure, Unit>> declineInvitation(String relationshipId);

  /// Leave current trainer
  Future<Either<Failure, Unit>> leaveTrainer(String relationshipId);

  /// Set a trainer as the primary (active) trainer for the client
  Future<Either<Failure, Unit>> setPrimaryTrainer({
    required String relationshipId,
    required String clientId,
  });

  // ===== Search =====

  /// Search for clients by email (for trainer to invite)
  Future<Either<Failure, List<Profile>>> searchClientsByEmail(String query);
}
