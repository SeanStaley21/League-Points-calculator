import 'package:flutter_test/flutter_test.dart';
import 'package:league_points_app/data/points_calculator.dart';
import 'package:league_points_app/models/racer.dart';
import 'package:league_points_app/models/weekly_result.dart';

void main() {
  group('with 13 scored positions (matches the real league table)', () {
    const scoredPositions = 13;

    test('pointsForPosition matches the league point table', () {
      expect(pointsForPosition(1, scoredPositions), 14);
      expect(pointsForPosition(2, scoredPositions), 12);
      expect(pointsForPosition(13, scoredPositions), 1);
      expect(pointsForPosition(14, scoredPositions), 0); // outside the table
      expect(pointsForPosition(null, scoredPositions), 0); // no result recorded
    });

    test('computeTotal sums all weeks when there are more than one', () {
      const results = [
        WeeklyResult(weekNumber: 1, finishPosition: 1), // 14 pts
        WeeklyResult(weekNumber: 2, finishPosition: 2), // 12 pts
        WeeklyResult(weekNumber: 3, finishPosition: 3), // 11 pts
      ];
      // Lowest week (11 pts) is dropped: 14 + 12 = 26.
      expect(computeTotal(results, scoredPositions), 26);
    });

    test('computeTotal drops a missed week (0 pts) rather than penalizing twice', () {
      const results = [
        WeeklyResult(weekNumber: 1, finishPosition: 1), // 14 pts
        WeeklyResult(weekNumber: 2), // no result recorded -> 0 pts, dropped
      ];
      expect(computeTotal(results, scoredPositions), 14);
    });

    test('computeTotal with only one week drops it, leaving 0', () {
      const results = [
        WeeklyResult(weekNumber: 1, finishPosition: 1),
      ];
      expect(computeTotal(results, scoredPositions), 0);
    });

    test('computeTotal with no weeks is 0', () {
      expect(computeTotal(const [], scoredPositions), 0);
    });
  });

  test('scoredPositions is configurable and rescales the points table', () {
    // 14 scored positions: 1st = 15, 2nd = 13, ..., 14th = 1.
    const scoredPositions = 14;
    expect(pointsForPosition(1, scoredPositions), 15);
    expect(pointsForPosition(2, scoredPositions), 13);
    expect(pointsForPosition(14, scoredPositions), 1);
    expect(pointsForPosition(15, scoredPositions), 0);
  });

  test('rankByTotalPoints sorts descending without mutating input', () {
    const scoredPositions = 13;
    final racers = [
      Racer(
        firstName: 'A',
        lastName: 'Racer',
        weeklyResults: const [
          WeeklyResult(weekNumber: 1, finishPosition: 5),
          WeeklyResult(weekNumber: 2, finishPosition: 5),
        ],
      ),
      Racer(
        firstName: 'B',
        lastName: 'Racer',
        weeklyResults: const [
          WeeklyResult(weekNumber: 1, finishPosition: 1),
          WeeklyResult(weekNumber: 2, finishPosition: 1),
        ],
      ),
      Racer(
        firstName: 'C',
        lastName: 'Racer',
        weeklyResults: const [
          WeeklyResult(weekNumber: 1, finishPosition: 3),
          WeeklyResult(weekNumber: 2, finishPosition: 3),
        ],
      ),
    ];

    final ranked = rankByTotalPoints(racers, scoredPositions);

    expect(ranked.map((r) => r.firstName).toList(), ['B', 'C', 'A']);
    expect(racers.map((r) => r.firstName).toList(), ['A', 'B', 'C']);
  });
}
