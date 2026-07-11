import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/season_document.dart';
import '../models/division.dart';
import '../models/kart.dart';
import '../models/racer.dart';
import '../models/weekly_result.dart';
import '../widgets/kart_pool_dialog.dart';
import '../widgets/weight_cell.dart';

/// Kart pick order for a single week, one column per division, side by side
/// (mirroring the Home screen's Weekly Standings layout). Each division's
/// racers are sorted heaviest-first -- that division's own pick order -- and
/// kart assignment is exclusive within that division only: divisions race at
/// separate times, so the same kart number can be picked by one racer per
/// division without conflict.
class KartPickOrderScreen extends StatefulWidget {
  const KartPickOrderScreen({super.key});

  @override
  State<KartPickOrderScreen> createState() => _KartPickOrderScreenState();
}

class _KartPickOrderScreenState extends State<KartPickOrderScreen> {
  int _week = 1;
  int? _selectedDivisionIndex;
  int? _selectedRacerIndex;

  Future<void> _manageKartPool(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SeasonDocument>(),
        child: KartPoolDialog(week: _week),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = context.watch<SeasonDocument>();
    final season = doc.season;
    final weekCount = season.weekCount;
    if (weekCount > 0 && _week > weekCount) _week = weekCount;

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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Manage kart pool',
            onPressed: () => _manageKartPool(context),
          ),
        ],
      ),
      body: season.divisions.isEmpty
          ? const Center(child: Text('No racers yet. Add racers in a division first.'))
          : Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var d = 0; d < season.divisions.length; d++)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _DivisionPickColumn(
                          division: season.divisions[d],
                          divisionIndex: d,
                          week: _week,
                          kartPool: season.kartPool,
                          selectedRacerIndex:
                              _selectedDivisionIndex == d ? _selectedRacerIndex : null,
                          onSelectRacer: (racerIndex) => setState(() {
                            if (_selectedDivisionIndex == d &&
                                _selectedRacerIndex == racerIndex) {
                              _selectedDivisionIndex = null;
                              _selectedRacerIndex = null;
                            } else {
                              _selectedDivisionIndex = d;
                              _selectedRacerIndex = racerIndex;
                            }
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PickEntry {
  _PickEntry({required this.index, required this.racer, required this.result});

  final int index;
  final Racer racer;
  final WeeklyResult result;
}

class _DivisionPickColumn extends StatelessWidget {
  const _DivisionPickColumn({
    required this.division,
    required this.divisionIndex,
    required this.week,
    required this.kartPool,
    required this.selectedRacerIndex,
    required this.onSelectRacer,
  });

  final Division division;
  final int divisionIndex;
  final int week;
  final List<Kart> kartPool;
  final int? selectedRacerIndex;
  final ValueChanged<int> onSelectRacer;

  @override
  Widget build(BuildContext context) {
    final doc = context.read<SeasonDocument>();

    final entries = [
      for (var i = 0; i < division.racers.length; i++)
        _PickEntry(
          index: i,
          racer: division.racers[i],
          result: division.racers[i].weeklyResults.firstWhere(
            (r) => r.weekNumber == week,
            orElse: () => WeeklyResult(weekNumber: week),
          ),
        ),
    ]..sort((a, b) => (b.result.weight ?? 0).compareTo(a.result.weight ?? 0));

    final takenInDivision = <int>{
      for (final e in entries)
        if (e.result.kartNumber != null) e.result.kartNumber!,
    };

    final karts = kartPool.where((k) => k.classType == division.kartClass).toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(division.name, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No racers'),
              )
            else
              for (var rank = 0; rank < entries.length; rank++)
                _buildRow(context, doc, entries[rank], rank, takenInDivision, karts),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, SeasonDocument doc, _PickEntry entry, int rank,
      Set<int> takenInDivision, List<Kart> karts) {
    final isSelected = selectedRacerIndex == entry.index;
    return Column(
      children: [
        ListTile(
          selected: isSelected,
          selectedTileColor:
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
          leading: CircleAvatar(child: Text('${rank + 1}')),
          title: Text(entry.racer.fullName),
          subtitle: Text(entry.result.kartNumber == null
              ? division.name
              : '${division.name} · Kart ${entry.result.kartNumber}'),
          onTap: () => onSelectRacer(entry.index),
          trailing: WeightCell(
            weight: entry.result.weight,
            onChanged: (weight) =>
                doc.updateWeeklyWeight(divisionIndex, entry.index, week, weight),
          ),
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: karts.isEmpty
                ? const Text('No karts in this pool yet. Add some via the settings icon above.')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kart in karts)
                        _kartChip(doc, entry, kart, takenInDivision),
                    ],
                  ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _kartChip(
      SeasonDocument doc, _PickEntry entry, Kart kart, Set<int> takenInDivision) {
    final isAssignedToSelected = entry.result.kartNumber == kart.number;
    final isDown = kart.isDownForWeek(week);
    final isTakenByOther = !isAssignedToSelected && takenInDivision.contains(kart.number);
    final disabled = isDown || isTakenByOther;

    String? label;
    if (isDown) label = 'down';
    if (isTakenByOther) label = 'taken';

    return FilterChip(
      label: Text(label == null ? 'Kart ${kart.number}' : 'Kart ${kart.number} ($label)'),
      selected: isAssignedToSelected,
      onSelected: disabled
          ? null
          : (_) {
              final newValue = isAssignedToSelected ? null : kart.number;
              doc.updateWeeklyKartNumber(divisionIndex, entry.index, week, newValue);
            },
    );
  }
}
