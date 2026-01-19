import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/trainer_client.dart';
import '../providers/client_provider.dart';
import '../widgets/client_checkins_tab.dart';
import '../widgets/client_info_header.dart';
import '../widgets/client_plans_tab.dart';
import '../widgets/client_workouts_tab.dart';

/// Screen displaying detailed information about a client for trainers.
/// Features three tabs: Check-ins, Workouts, and Plans.
class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(trainerClientsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return clientsAsync.when(
      data: (clients) {
        // Find the specific client
        final client = clients.firstWhere(
          (c) => c.clientId == widget.clientId,
          orElse: () => TrainerClient(
            id: '',
            trainerId: '',
            clientId: widget.clientId,
            clientName: 'Unknown Client',
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(client.clientName ?? 'Client Details'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Check-ins', icon: Icon(Icons.checklist)),
                Tab(text: 'Workouts', icon: Icon(Icons.fitness_center)),
                Tab(text: 'Plans', icon: Icon(Icons.calendar_today)),
              ],
            ),
          ),
          body: Column(
            children: [
              ClientInfoHeader(client: client),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ClientCheckinsTab(clientId: widget.clientId),
                    ClientWorkoutsTab(clientId: widget.clientId),
                    ClientPlansTab(clientId: widget.clientId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Client Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Client Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(trainerClientsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
