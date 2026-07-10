import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:league_points_app/data/points_calculator.dart';
import 'package:league_points_app/data/season_document.dart';
import 'package:league_points_app/models/division.dart';
import 'package:league_points_app/models/racer.dart';
import 'package:league_points_app/models/season.dart';
import 'package:league_points_app/models/weekly_result.dart';

void main() {
  test('Season round-trips through JSON with all fields intact', () {
    final season = Season(
      name: '2026 Summer League',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 7, 27),
      weekCount: 8,
      scoredPositions: 13,
      divisions: [
        Division(
          name: 'Pro 1',
          sortOrder: 0,
          racers: [
            Racer(
              firstName: 'Jane',
              lastName: 'Doe',
              sortOrder: 0,
              weeklyResults: const [
                WeeklyResult(weekNumber: 1, finishPosition: 1), // 14 pts
                WeeklyResult(weekNumber: 2), // no result -> 0 pts, dropped
              ],
            ),
          ],
        ),
      ],
    );

    final jsonString = jsonEncode({
      'formatVersion': 1,
      'season': season.toJson(),
    });
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final restored = Season.fromJson(decoded['season'] as Map<String, dynamic>);

    expect(restored.name, season.name);
    expect(restored.startDate, season.startDate);
    expect(restored.endDate, season.endDate);
    expect(restored.weekCount, season.weekCount);
    expect(restored.scoredPositions, 13);
    expect(restored.divisions.length, 1);
    expect(restored.divisions[0].name, 'Pro 1');
    expect(restored.divisions[0].racers.length, 1);
    final racer = restored.divisions[0].racers[0];
    expect(racer.fullName, 'Jane Doe');
    // Lowest week (the missed week, 0 pts) is dropped: total = 14.
    expect(racer.totalPoints(restored.scoredPositions), 14);
    expect(racer.weeklyResults[0].finishPosition, 1);
    expect(pointsForResult(racer.weeklyResults[1], restored.scoredPositions), 0);
  });

  test('Division.leader picks the racer with the highest total points', () {
    const scoredPositions = 13;
    final division = Division(
      name: 'Pro 1',
      racers: [
        Racer(
          firstName: 'Low',
          lastName: 'Scorer',
          weeklyResults: const [
            WeeklyResult(weekNumber: 1, finishPosition: 8), // 6 pts
            WeeklyResult(weekNumber: 2, finishPosition: 8), // 6 pts
          ],
        ),
        Racer(
          firstName: 'High',
          lastName: 'Scorer',
          weeklyResults: const [
            WeeklyResult(weekNumber: 1, finishPosition: 1), // 14 pts
            WeeklyResult(weekNumber: 2, finishPosition: 1), // 14 pts
          ],
        ),
      ],
    );

    expect(division.leader(scoredPositions)?.fullName, 'High Scorer');
  });

  test('updateWeeklyWeight sets and clears a racer\'s weight for one week', () {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'Jane', lastName: 'Doe');

    doc.updateWeeklyWeight(0, 0, 1, 180.5);
    expect(doc.season.divisions[0].racers[0].weeklyResults[0].weight, 180.5);

    doc.updateWeeklyWeight(0, 0, 1, null);
    expect(doc.season.divisions[0].racers[0].weeklyResults[0].weight, isNull);
  });
}
