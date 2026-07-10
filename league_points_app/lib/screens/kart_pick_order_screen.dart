import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/season_document.dart';
import '../models/weekly_result.dart';
import '../widgets/weight_cell.dart';

class _PickOrderEntry {
  _PickOrderEntry({
    required this.divisionIndex,
    required this.racerIndex,
    required this.divisionName,
    required this.racerName,
    required this.weight,
  });

  final int divisionIndex;
  final int racerIndex;
  final String divisionName;
  final String racerName;
  final double? weight;
}

/// Cross-division kart pick order for a single week: every racer in the
/// season, sorted by weight with the heaviest driver first, so the league
/// can call out picks in a fair order before that week's heats.
class KartPickOrderScreen extends StatefulWidget {
  const KartPickOrderScreen({super.key});

  @override
  State<KartPickOrderScreen> createState() => _KartPickOrderScreenState();
}

class _KartPickOrderScreenState extends State<KartPickOrderScreen> {
  int _week = 1;

  @override
  Widget build(BuildContext context) {
    final doc = context.watch<SeasonDocument>();
    final season = doc.season;
    final weekCount = season.weekCount;
    if (weekCount > 0 && _week > weekCount) _week = weekCount;

    final entries = <_PickOrderEntry>[];
    for (var d = 0; d < season.divisions.length; d++) {
      final division = season.divisions[d];
      for (var r = 0; r < division.racers.length; r++) {
        final racer = division.racers[r];
        final result = racer.weeklyResults.firstWhere(
          (wr) => wr.weekNumber == _week,
          orElse: () => WeeklyResult(weekNumber: _week),
        );
        entries.add(_PickOrderEntry(
          divisionIndex: d,
          racerIndex: r,
          divisionName: division.name,
          racerName: racer.fullName,
          weight: result.weight,
        ));
      }
    }
    entries.sort((a, b) => (b.weight ?? 0).compareTo(a.weight ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kart Pick Order'),
        actions: [
          if (weekCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: DropdownButton<int>(
                  value: _week,
                  items: [
                    for (var w = 1; w <= weekCount; w++)
                      DropdownMenuItem(value: w, child: Text('Week $w')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _week = value);
                  },
                ),
              ),
            ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No racers yet. Add racers in a division first.'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  key: ValueKey('${entry.divisionIndex}-${entry.racerIndex}'),
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(entry.racerName),
                  subtitle: Text(entry.divisionName),
                  trailing: WeightCell(
                    weight: entry.weight,
                    onChanged: (weight) => doc.updateWeeklyWeight(
                        entry.divisionIndex, entry.racerIndex, _week, weight),
                  ),
                );
              },
            ),
    );
  }
}
