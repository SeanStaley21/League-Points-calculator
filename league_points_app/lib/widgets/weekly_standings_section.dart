import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/points_calculator.dart';
import '../data/season_document.dart';
import '../models/division.dart';
import '../models/racer.dart';
import '../models/season.dart';
import '../models/weekly_result.dart';
import 'week_position_cell.dart';

/// Home screen section showing, for a single selected week, every
/// division's racers side by side (alphabetical by name) with their finish
/// position that week, editable in place. The selected week is kept in
/// local widget state so it survives rebuilds of [Season] (e.g. entering a
/// finish position) for as long as the Home screen stays on the navigation
/// stack, but resets to week 1 the next time the app is opened.
class WeeklyStandingsSection extends StatefulWidget {
  const WeeklyStandingsSection({super.key, required this.season});

  final Season season;

  @override
  State<WeeklyStandingsSection> createState() => _WeeklyStandingsSectionState();
}

class _WeeklyStandingsSectionState extends State<WeeklyStandingsSection> {
  int _selectedWeek = 1;

  @override
  Widget build(BuildContext context) {
    final weekCount = widget.season.weekCount;
    if (widget.season.divisions.isEmpty || weekCount < 1) {
      return const SizedBox.shrink();
    }
    final selectedWeek = _selectedWeek.clamp(1, weekCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Text('Weekly Standings', style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: [
                  for (var week = 1; week <= weekCount; week++)
                    ButtonSegment(value: week, label: Text('Wk $week')),
                ],
                selected: {selectedWeek},
                onSelectionChanged: (selection) =>
                    setState(() => _selectedWeek = selection.first),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var divisionIndex = 0;
                    divisionIndex < widget.season.divisions.length;
                    divisionIndex++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _DivisionWeekColumn(
                      division: widget.season.divisions[divisionIndex],
                      divisionIndex: divisionIndex,
                      weekNumber: selectedWeek,
                      scoredPositions: widget.season.scoredPositions,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DivisionWeekColumn extends StatelessWidget {
  const _DivisionWeekColumn({
    required this.division,
    required this.divisionIndex,
    required this.weekNumber,
    required this.scoredPositions,
  });

  final Division division;
  final int divisionIndex;
  final int weekNumber;
  final int scoredPositions;

  WeeklyResult _resultFor(Racer racer) => racer.weeklyResults.firstWhere(
        (r) => r.weekNumber == weekNumber,
        orElse: () => WeeklyResult(weekNumber: weekNumber),
      );

  @override
  Widget build(BuildContext context) {
    // Pair each racer with its index in the division's stored (unsorted)
    // racer list, since that original index is what SeasonDocument's update
    // methods address racers by, not its position in this alphabetical view.
    final indexedRacers = [
      for (var i = 0; i < division.racers.length; i++) (index: i, racer: division.racers[i]),
    ]..sort((a, b) => a.racer.fullName.compareTo(b.racer.fullName));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(division.name, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (indexedRacers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No racers'),
              )
            else
              DataTable(
                columnSpacing: 16,
                headingRowHeight: 32,
                dataRowMinHeight: 76,
                dataRowMaxHeight: 76,
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Finish')),
                  DataColumn(label: Text('Kart')),
                ],
                rows: [
                  for (final entry in indexedRacers)
                    DataRow(cells: [
                      DataCell(Text(entry.racer.fullName)),
                      DataCell(WeekPositionCell(
                        finishPosition: _resultFor(entry.racer).finishPosition,
                        points: pointsForResult(_resultFor(entry.racer), scoredPositions),
                        onChanged: (position) =>
                            context.read<SeasonDocument>().updateWeeklyFinishPosition(
                                  divisionIndex,
                                  entry.index,
                                  weekNumber,
                                  position,
                                ),
                      )),
                      DataCell(Text(_resultFor(entry.racer).kartNumber?.toString() ?? '-')),
                    ]),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
