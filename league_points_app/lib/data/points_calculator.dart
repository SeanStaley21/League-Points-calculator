/// Pure functions for points/standings math. No Flutter/IO dependencies so
/// they're trivially unit-testable.
library;

import '../models/racer.dart';
import '../models/weekly_result.dart';

/// Points for a given finish position, out of [scoredPositions] total scored
/// positions for the season. Matches the league's real points table at
/// scoredPositions=13 (1st=14, 2nd=12, 3rd=11, ..., 13th=1): the winner gets
/// one point more than 2nd place, and each position after that is worth one
/// point less than the position ahead of it, down to 1 point for last place.
/// Positions beyond [scoredPositions] (or no recorded finish) score 0.
int pointsForPosition(int? position, int scoredPositions) {
  if (position == null || position < 1 || position > scoredPositions) return 0;
  if (position == 1) return scoredPositions + 1;
  return scoredPositions + 1 - position;
}

int pointsForResult(WeeklyResult result, int scoredPositions) =>
    pointsForPosition(result.finishPosition, scoredPositions);

/// Sums a racer's weekly points, dropping their single lowest-scoring week,
/// per league rules ("your lowest week will not be counted"). If there are
/// no weeks at all, returns 0. With only one week, that week is the lowest
/// and gets dropped, so the total is 0 until a second week exists.
int computeTotal(List<WeeklyResult> results, int scoredPositions) {
  if (results.isEmpty) return 0;
  final weeklyPoints =
      results.map((r) => pointsForResult(r, scoredPositions)).toList();
  final sum = weeklyPoints.fold(0, (a, b) => a + b);
  final lowest = weeklyPoints.reduce((a, b) => a < b ? a : b);
  return sum - lowest;
}

/// Returns the racers in [racers] sorted by total points, descending.
List<Racer> rankByTotalPoints(List<Racer> racers, int scoredPositions) {
  final sorted = List<Racer>.from(racers);
  sorted.sort((a, b) => b
      .totalPoints(scoredPositions)
      .compareTo(a.totalPoints(scoredPositions)));
  return sorted;
}
