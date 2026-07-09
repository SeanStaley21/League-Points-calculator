/// Pure functions for points/standings math. No Flutter/IO dependencies so
/// they're trivially unit-testable.
library;

import '../models/racer.dart';
import '../models/weekly_result.dart';

/// Sums a racer's weekly points, dropping their single lowest-scoring week,
/// per league rules ("your lowest week will not be counted"). If there are
/// no weeks at all, returns 0. With only one week, that week is the lowest
/// and gets dropped, so the total is 0 until a second week exists.
int computeTotal(List<WeeklyResult> results) {
  if (results.isEmpty) return 0;
  final weeklyPoints = results.map((r) => r.points).toList();
  final sum = weeklyPoints.fold(0, (a, b) => a + b);
  final lowest = weeklyPoints.reduce((a, b) => a < b ? a : b);
  return sum - lowest;
}

/// Returns the racers in [racers] sorted by total points, descending.
List<Racer> rankByTotalPoints(List<Racer> racers) {
  final sorted = List<Racer>.from(racers);
  sorted.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
  return sorted;
}
