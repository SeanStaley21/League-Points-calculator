import 'package:flutter/material.dart';

import '../models/division.dart';

/// A small card on the Home screen showing a division's current leader.
class StandingsSnapshotCard extends StatelessWidget {
  const StandingsSnapshotCard({super.key, required this.division});

  final Division division;

  @override
  Widget build(BuildContext context) {
    final leader = division.leader;
    return Card(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              division.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (leader == null)
              const Text('No racers yet')
            else ...[
              Text(leader.fullName, style: Theme.of(context).textTheme.bodyLarge),
              Text('${leader.totalPoints} pts • leader'),
            ],
          ],
        ),
      ),
    );
  }
}
