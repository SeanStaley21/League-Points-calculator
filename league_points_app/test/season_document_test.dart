import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:league_points_app/data/points_calculator.dart';
import 'package:league_points_app/data/season_document.dart';
import 'package:league_points_app/models/division.dart';
import 'package:league_points_app/models/kart.dart';
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

  test('addRacer defaults weight to 0 and copies a given weight into every week', () {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'No', lastName: 'Weight');
    doc.addRacer(0, firstName: 'Heavy', lastName: 'Racer', weight: 210);

    final noWeight = doc.season.divisions[0].racers[0];
    expect(noWeight.weight, 0);
    expect(noWeight.weeklyResults.every((r) => r.weight == 0), isTrue);

    final heavy = doc.season.divisions[0].racers[1];
    expect(heavy.weight, 210);
    expect(heavy.weeklyResults.every((r) => r.weight == 210), isTrue);
  });

  test('updateRacerInfo updates the season-long default weight', () {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'Jane', lastName: 'Doe');

    doc.updateRacerInfo(0, 0, weight: 150);
    expect(doc.season.divisions[0].racers[0].weight, 150);
    // Only the season-long default changes; already-created weekly results
    // are untouched (still edited per-week via the Kart Pick Order screen).
    expect(doc.season.divisions[0].racers[0].weeklyResults[0].weight, 0);
  });

  test('addRacer and updateRacerInfo set and clear the optional importName/phone/email fields', () {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0,
        firstName: 'Jane',
        lastName: 'Doe',
        importName: 'J. Doe',
        phone: '555-1234',
        email: 'jane@example.com');

    final added = doc.season.divisions[0].racers[0];
    expect(added.importName, 'J. Doe');
    expect(added.phone, '555-1234');
    expect(added.email, 'jane@example.com');

    doc.updateRacerInfo(0, 0, clearImportName: true, clearPhone: true, clearEmail: true);
    final cleared = doc.season.divisions[0].racers[0];
    expect(cleared.importName, isNull);
    expect(cleared.phone, isNull);
    expect(cleared.email, isNull);
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

  test('updateWeeklyKartNumber sets and clears a racer\'s kart for one week', () {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'Jane', lastName: 'Doe');

    doc.updateWeeklyKartNumber(0, 0, 1, 14);
    expect(doc.season.divisions[0].racers[0].weeklyResults[0].kartNumber, 14);

    doc.updateWeeklyKartNumber(0, 0, 1, null);
    expect(doc.season.divisions[0].racers[0].weeklyResults[0].kartNumber, isNull);
  });

  test('addKart/removeKart manage the season kart pool, deduped by number', () {
    final doc = SeasonDocument();
    doc.addKart(14, KartClass.pro);
    doc.addKart(75, KartClass.junior);
    doc.addKart(14, KartClass.junior); // duplicate number, no-op

    expect(doc.season.kartPool.length, 2);
    expect(doc.season.kartPool.firstWhere((k) => k.number == 14).classType,
        KartClass.pro);

    doc.removeKart(14);
    expect(doc.season.kartPool.map((k) => k.number), [75]);
  });

  test('setKartDownForWeek marks/clears a kart as down for one week only', () {
    final doc = SeasonDocument();
    doc.addKart(14, KartClass.pro);

    doc.setKartDownForWeek(14, 2, true);
    final kart = doc.season.kartPool.first;
    expect(kart.isDownForWeek(2), isTrue);
    expect(kart.isDownForWeek(1), isFalse);

    doc.setKartDownForWeek(14, 2, false);
    expect(doc.season.kartPool.first.isDownForWeek(2), isFalse);
  });

  test('updateDivisionClass changes which kart pool a division uses', () {
    final doc = SeasonDocument();
    doc.addDivision('Juniors');
    expect(doc.season.divisions[0].kartClass, KartClass.pro);

    doc.updateDivisionClass(0, KartClass.junior);
    expect(doc.season.divisions[0].kartClass, KartClass.junior);
  });
}
