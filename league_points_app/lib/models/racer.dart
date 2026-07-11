import '../data/points_calculator.dart';
import 'weekly_result.dart';

class Racer {
  final String firstName;
  final String lastName;
  final int sortOrder;
  final List<WeeklyResult> weeklyResults;

  /// Season-long default weight, set once when the racer is added to the
  /// roster and copied into each week's [WeeklyResult.weight] at creation
  /// time. Defaults to 0 rather than being nullable/unset.
  final double weight;

  /// Optional name to match against rows in an auto-imported Clubspeed
  /// export, for cases where that export doesn't use "firstName lastName"
  /// (e.g. a nickname on file at the track). Falls back to [fullName] for
  /// matching when unset.
  final String? importName;
  final String? phone;
  final String? email;

  const Racer({
    required this.firstName,
    required this.lastName,
    this.sortOrder = 0,
    this.weeklyResults = const [],
    this.weight = 0,
    this.importName,
    this.phone,
    this.email,
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
    double? weight,
    String? importName,
    bool clearImportName = false,
    String? phone,
    bool clearPhone = false,
    String? email,
    bool clearEmail = false,
  }) {
    return Racer(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      sortOrder: sortOrder ?? this.sortOrder,
      weeklyResults: weeklyResults ?? this.weeklyResults,
      weight: weight ?? this.weight,
      importName: clearImportName ? null : (importName ?? this.importName),
      phone: clearPhone ? null : (phone ?? this.phone),
      email: clearEmail ? null : (email ?? this.email),
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
        'weight': weight,
        'importName': importName,
        'phone': phone,
        'email': email,
      };

  factory Racer.fromJson(Map<String, dynamic> json) {
    return Racer(
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      weeklyResults: (json['weeklyResults'] as List<dynamic>? ?? [])
          .map((r) => WeeklyResult.fromJson(r as Map<String, dynamic>))
          .toList(),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      importName: json['importName'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }
}
