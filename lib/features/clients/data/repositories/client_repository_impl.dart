import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/profile.dart';
import '../../domain/entities/trainer_client.dart';
import '../../domain/repositories/client_repository.dart';

class SupabaseClientRepository implements ClientRepository {
  SupabaseClientRepository(this._client);

  final SupabaseClient _client;

  // ===== For Trainers =====

  @override
  Future<Either<Failure, List<TrainerClient>>> getTrainerClients(
      String trainerId) async {
    try {
      final response = await _client
          .from('trainer_clients')
          .select('*, profiles!trainer_clients_client_id_fkey(full_name, email)')
          .eq('trainer_id', trainerId)
          .order('created_at', ascending: false);

      final clients = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        final clientProfile = data['profiles'] as Map<String, dynamic>?;

        return TrainerClient.fromJson(_snakeToCamel({
          ...data,
          'client_name': clientProfile?['full_name'],
          'client_email': clientProfile?['email'],
        }..remove('profiles')));
      }).toList();

      return right(clients);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load clients: $e'));
    }
  }

  @override
  Future<Either<Failure, TrainerClient>> inviteClient({
    required String trainerId,
    required String clientEmail,
  }) async {
    try {
      // Find client by email
      final clientResponse = await _client
          .from('profiles')
          .select('id, full_name, email')
          .eq('email', clientEmail)
          .eq('role', 'client')
          .maybeSingle();

      if (clientResponse == null) {
        return left(const ValidationFailure(
          message: 'No client found with this email address',
        ));
      }

      final clientId = clientResponse['id'] as String;

      // Check if relationship already exists
      final existingResponse = await _client
          .from('trainer_clients')
          .select()
          .eq('trainer_id', trainerId)
          .eq('client_id', clientId)
          .maybeSingle();

      if (existingResponse != null) {
        final status = existingResponse['status'] as String;
        if (status == 'active') {
          return left(const ValidationFailure(
            message: 'This client is already linked to you',
          ));
        } else if (status == 'pending') {
          return left(const ValidationFailure(
            message: 'Invitation already sent to this client',
          ));
        }
        // If inactive, reactivate as pending
        final updateResponse = await _client
            .from('trainer_clients')
            .update({'status': 'pending'})
            .eq('id', existingResponse['id'] as String)
            .select('*, profiles!trainer_clients_client_id_fkey(full_name, email)')
            .single();

        final clientProfile =
            updateResponse['profiles'] as Map<String, dynamic>?;

        return right(TrainerClient.fromJson(_snakeToCamel({
          ...updateResponse,
          'client_name': clientProfile?['full_name'],
          'client_email': clientProfile?['email'],
        }..remove('profiles'))));
      }

      // Create new relationship with pending status
      final response = await _client
          .from('trainer_clients')
          .insert({
            'trainer_id': trainerId,
            'client_id': clientId,
            'status': 'pending',
          })
          .select('*, profiles!trainer_clients_client_id_fkey(full_name, email)')
          .single();

      final clientProfile = response['profiles'] as Map<String, dynamic>?;

      return right(TrainerClient.fromJson(_snakeToCamel({
        ...response,
        'client_name': clientProfile?['full_name'],
        'client_email': clientProfile?['email'],
      }..remove('profiles'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to invite client: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeClient(String relationshipId) async {
    try {
      await _client
          .from('trainer_clients')
          .update({'status': 'inactive'})
          .eq('id', relationshipId);

      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to remove client: $e'));
    }
  }

  @override
  Future<Either<Failure, Profile>> getClientProfile(String clientId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', clientId)
          .single();

      return right(Profile.fromJson(_snakeToCamel(response)));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load client profile: $e'));
    }
  }

  // ===== For Clients =====

  @override
  Future<Either<Failure, List<TrainerClient>>> getClientTrainers(
      String clientId) async {
    try {
      final response = await _client
          .from('trainer_clients')
          .select(
              '*, profiles!trainer_clients_trainer_id_fkey(full_name, email)')
          .eq('client_id', clientId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final trainers = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        final trainerProfile = data['profiles'] as Map<String, dynamic>?;

        return TrainerClient.fromJson(_snakeToCamel({
          ...data,
          'trainer_name': trainerProfile?['full_name'],
          'trainer_email': trainerProfile?['email'],
        }..remove('profiles')));
      }).toList();

      return right(trainers);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load trainers: $e'));
    }
  }

  @override
  Future<Either<Failure, List<TrainerClient>>> getPendingInvitations(
      String clientId) async {
    try {
      final response = await _client
          .from('trainer_clients')
          .select(
              '*, profiles!trainer_clients_trainer_id_fkey(full_name, email)')
          .eq('client_id', clientId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final invitations = (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        final trainerProfile = data['profiles'] as Map<String, dynamic>?;

        return TrainerClient.fromJson(_snakeToCamel({
          ...data,
          'trainer_name': trainerProfile?['full_name'],
          'trainer_email': trainerProfile?['email'],
        }..remove('profiles')));
      }).toList();

      return right(invitations);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to load invitations: $e'));
    }
  }

  @override
  Future<Either<Failure, TrainerClient>> acceptInvitation(
      String relationshipId) async {
    try {
      // First, deactivate any existing active trainer relationship
      final existingResponse = await _client
          .from('trainer_clients')
          .select('client_id')
          .eq('id', relationshipId)
          .single();

      final clientId = existingResponse['client_id'] as String;

      await _client
          .from('trainer_clients')
          .update({'status': 'inactive'})
          .eq('client_id', clientId)
          .eq('status', 'active');

      // Now accept the new invitation
      final response = await _client
          .from('trainer_clients')
          .update({'status': 'active'})
          .eq('id', relationshipId)
          .select(
              '*, profiles!trainer_clients_trainer_id_fkey(full_name, email)')
          .single();

      final trainerProfile = response['profiles'] as Map<String, dynamic>?;

      return right(TrainerClient.fromJson(_snakeToCamel({
        ...response,
        'trainer_name': trainerProfile?['full_name'],
        'trainer_email': trainerProfile?['email'],
      }..remove('profiles'))));
    } catch (e) {
      return left(ServerFailure(message: 'Failed to accept invitation: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> declineInvitation(String relationshipId) async {
    try {
      await _client
          .from('trainer_clients')
          .delete()
          .eq('id', relationshipId)
          .eq('status', 'pending');

      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to decline invitation: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> leaveTrainer(String relationshipId) async {
    try {
      await _client
          .from('trainer_clients')
          .update({'status': 'inactive'})
          .eq('id', relationshipId);

      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to leave trainer: $e'));
    }
  }

  // ===== Search =====

  @override
  Future<Either<Failure, List<Profile>>> searchClientsByEmail(
      String query) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('role', 'client')
          .ilike('email', '%$query%')
          .limit(10);

      final profiles = (response as List)
          .map((json) =>
              Profile.fromJson(_snakeToCamel(json as Map<String, dynamic>)))
          .toList();

      return right(profiles);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to search clients: $e'));
    }
  }

  /// Convert snake_case keys to camelCase for Dart models
  Map<String, dynamic> _snakeToCamel(Map<String, dynamic> json) {
    return json.map((key, value) {
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      return MapEntry(camelKey, value);
    });
  }
}
