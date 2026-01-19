import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/checkin_provider.dart';

/// Screen showing check-in history.
class CheckinHistoryScreen extends ConsumerWidget {
  const CheckinHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(checkinsProvider());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in History'),
      ),
      body: checkinsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (checkins) {
          if (checkins.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No check-ins yet'),
                  SizedBox(height: 8),
                  Text('Start tracking your daily progress!'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: checkins.length,
            itemBuilder: (context, index) {
              final checkin = checkins[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(checkin.date.day.toString()),
                  ),
                  title: Text(
                    '${checkin.date.day}/${checkin.date.month}/${checkin.date.year}',
                  ),
                  subtitle: Text(
                    [
                      if (checkin.bodyweightKg != null)
                        '${checkin.bodyweightKg}kg',
                      if (checkin.steps != null) '${checkin.steps} steps',
                      if (checkin.workoutPlanId != null)
                        'Trained',
                    ].join(' • '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to detail/edit
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
