import 'package:flutter_test/flutter_test.dart';
import 'package:league_points_app/data/points_calculator.dart';
import 'package:league_points_app/models/racer.dart';
import 'package:league_points_app/models/weekly_result.dart';

void main() {
  test('pointsForFinishPosition matches the league point table', () {
    expect(pointsForFinishPosition(1), 14);
    expect(pointsForFinishPosition(2), 12);
    expect(pointsForFinishPosition(13), 1);
    expect(pointsForFinishPosition(14), 0); // outside the table
    expect(pointsForFinishPosition(null), 0); // no result recorded
  });

  test('computeTotal sums all weeks when there are more than one', () {
    const results = [
      WeeklyResult(weekNumber: 1, finishPosition: 1), // 14 pts
      WeeklyResult(weekNumber: 2, finishPosition: 2), // 12 pts
      WeeklyResult(weekNumber: 3, finishPosition: 3), // 11 pts
    ];
    // Lowest week (11 pts) is dropped: 14 + 12 = 26.
    expect(computeTotal(results), 26);
  });

  test('computeTotal drops a missed week (0 pts) rather than penalizing twice', () {
    const results = [
      WeeklyResult(weekNumber: 1, finishPosition: 1), // 14 pts
      WeeklyResult(weekNumber: 2), // no result recorded -> 0 pts, dropped
    ];
    expect(computeTotal(results), 14);
  });

  test('computeTotal with only one week drops it, leaving 0', () {
    const results = [
      WeeklyResult(weekNumber: 1, finishPosition: 1), // 14 pts, but it's the only (lowest) week
    ];
    expect(computeTotal(results), 0);
  });

  test('computeTotal with no weeks is 0', () {
    expect(computeTotal(const []), 0);
  });

  test('rankByTotalPoints sorts descending without mutating input', () {
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

    final ranked = rankByTotalPoints(racers);

    expect(ranked.map((r) => r.firstName).toList(), ['B', 'C', 'A']);
    expect(racers.map((r) => r.firstName).toList(), ['A', 'B', 'C']);
  });
}
