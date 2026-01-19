import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/client_repository_impl.dart';
import '../../domain/entities/trainer_client.dart';
import '../../domain/repositories/client_repository.dart';

part 'client_provider.g.dart';

/// Provides the ClientRepository instance
@riverpod
ClientRepository clientRepository(ClientRepositoryRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabaseClientRepository(supabase);
}

// ===== For Trainers =====

/// Provides all clients for the current trainer
@riverpod
Future<List<TrainerClient>> trainerClients(TrainerClientsRef ref) async {
  final repo = ref.watch(clientRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (profile == null || profile.effectiveActiveRole != 'trainer') {
    return [];
  }

  final result = await repo.getTrainerClients(profile.id);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (clients) => clients,
  );
}

/// Notifier for inviting clients
@riverpod
class InviteClientNotifier extends _$InviteClientNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<Either<Failure, TrainerClient>> invite(String email) async {
    state = const AsyncLoading();

    final repo = ref.read(clientRepositoryProvider);
    final profile = ref.read(currentProfileProvider).valueOrNull;

    if (profile == null) {
      state = const AsyncData(null);
      return left(const AuthFailure(message: 'Not authenticated'));
    }

    final result = await repo.inviteClient(
      trainerId: profile.id,
      clientEmail: email.trim().toLowerCase(),
    );

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    // Refresh the client list
    ref.invalidate(trainerClientsProvider);

    return result;
  }
}

/// Search for clients by email
@riverpod
Future<List<Profile>> searchClients(
  SearchClientsRef ref,
  String query,
) async {
  if (query.length < 3) {
    return [];
  }

  final repo = ref.watch(clientRepositoryProvider);
  final result = await repo.searchClientsByEmail(query);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (profiles) => profiles,
  );
}

// ===== For Clients =====

/// Provides the client's trainers (can have multiple)
@riverpod
Future<List<TrainerClient>> clientTrainers(ClientTrainersRef ref) async {
  final repo = ref.watch(clientRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (profile == null || profile.effectiveActiveRole != 'client') {
    return [];
  }

  final result = await repo.getClientTrainers(profile.id);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (trainers) => trainers,
  );
}

/// Provides the client's primary (active) trainer
@riverpod
Future<TrainerClient?> primaryTrainer(PrimaryTrainerRef ref) async {
  final trainers = await ref.watch(clientTrainersProvider.future);

  // Find the primary trainer, or return the first one if none is marked primary
  final primary = trainers.where((t) => t.isPrimary).firstOrNull;
  if (primary != null) return primary;

  // If no primary is set but trainers exist, return null (user should select one)
  return trainers.isNotEmpty ? trainers.first : null;
}

/// Notifier for setting the primary trainer
@riverpod
class PrimaryTrainerNotifier extends _$PrimaryTrainerNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<Either<Failure, Unit>> setPrimary(String relationshipId) async {
    state = const AsyncLoading();

    final repo = ref.read(clientRepositoryProvider);
    final profile = ref.read(currentProfileProvider).valueOrNull;

    if (profile == null) {
      state = const AsyncData(null);
      return left(const AuthFailure(message: 'Not authenticated'));
    }

    final result = await repo.setPrimaryTrainer(
      relationshipId: relationshipId,
      clientId: profile.id,
    );

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    // Refresh trainers list to update isPrimary flags
    ref.invalidate(clientTrainersProvider);

    return result;
  }
}

/// Provides pending invitations for the client
@riverpod
Future<List<TrainerClient>> pendingInvitations(PendingInvitationsRef ref) async {
  final repo = ref.watch(clientRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (profile == null || profile.effectiveActiveRole != 'client') {
    return [];
  }

  final result = await repo.getPendingInvitations(profile.id);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (invitations) => invitations,
  );
}

/// Notifier for handling invitations (accept/decline)
@riverpod
class InvitationNotifier extends _$InvitationNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<Either<Failure, TrainerClient>> accept(String relationshipId) async {
    state = const AsyncLoading();

    final repo = ref.read(clientRepositoryProvider);
    final result = await repo.acceptInvitation(relationshipId);

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    // Refresh data
    ref.invalidate(pendingInvitationsProvider);
    ref.invalidate(clientTrainersProvider);

    return result;
  }

  Future<Either<Failure, Unit>> decline(String relationshipId) async {
    state = const AsyncLoading();

    final repo = ref.read(clientRepositoryProvider);
    final result = await repo.declineInvitation(relationshipId);

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    // Refresh data
    ref.invalidate(pendingInvitationsProvider);

    return result;
  }

  Future<Either<Failure, Unit>> leaveTrainer(String relationshipId) async {
    state = const AsyncLoading();

    final repo = ref.read(clientRepositoryProvider);
    final result = await repo.leaveTrainer(relationshipId);

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );

    // Refresh data
    ref.invalidate(clientTrainersProvider);

    return result;
  }
}
