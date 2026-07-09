import '../data/points_calculator.dart';
import 'weekly_result.dart';

class Racer {
  final String firstName;
  final String lastName;
  final int sortOrder;
  final List<WeeklyResult> weeklyResults;

  const Racer({
    required this.firstName,
    required this.lastName,
    this.sortOrder = 0,
    this.weeklyResults = const [],
  });

  String get fullName => '$firstName $lastName';

  /// Total points across all weeks, with the lowest-scoring week dropped
  /// per league rules. [scoredPositions] is the season's configured number
  /// of scored finish positions. See [computeTotal].
  int totalPoints(int scoredPositions) =>
      computeTotal(weeklyResults, scoredPositions);

  Racer copyWith({
    String? firstName,
    String? lastName,
    int? sortOrder,
    List<WeeklyResult>? weeklyResults,
  }) {
    return Racer(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      sortOrder: sortOrder ?? this.sortOrder,
      weeklyResults: weeklyResults ?? this.weeklyResults,
    );
  }

  /// Returns a copy of this racer with the given week's result replaced.
  Racer withUpdatedWeek(int weekNumber, WeeklyResult Function(WeeklyResult) update) {
    final updated = weeklyResults
        .map((r) => r.weekNumber == weekNumber ? update(r) : r)
        .toList();
    return copyWith(weeklyResults: updated);
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'sortOrder': sortOrder,
        'weeklyResults': weeklyResults.map((r) => r.toJson()).toList(),
      };

  factory Racer.fromJson(Map<String, dynamic> json) {
    return Racer(
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      weeklyResults: (json['weeklyResults'] as List<dynamic>? ?? [])
          .map((r) => WeeklyResult.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
