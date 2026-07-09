/// Finish position -> points, matching the league's "Points calculator"
/// sheet. Positions outside this table (or no recorded finish) score 0.
const Map<int, int> pointsByFinishPosition = {
  1: 14,
  2: 12,
  3: 11,
  4: 10,
  5: 9,
  6: 8,
  7: 7,
  8: 6,
  9: 5,
  10: 4,
  11: 3,
  12: 2,
  13: 1,
};

int pointsForFinishPosition(int? position) {
  if (position == null) return 0;
  return pointsByFinishPosition[position] ?? 0;
}

class WeeklyResult {
  final int weekNumber;
  final int? finishPosition;
  // Reserved for a future auto-import feature (populating results from a
  // Clubspeed lap-time export). Unused by any screen today.
  final int? startPosition;
  final int? bestLapTimeMs;
  final int? averageLapTimeMs;
  final double? weight;
  final int? kartNumber;

  const WeeklyResult({
    required this.weekNumber,
    this.finishPosition,
    this.startPosition,
    this.bestLapTimeMs,
    this.averageLapTimeMs,
    this.weight,
    this.kartNumber,
  });

  /// Points for this week, derived from [finishPosition] via the league's
  /// points table. Never stored directly, so it can't drift out of sync.
  int get points => pointsForFinishPosition(finishPosition);

  WeeklyResult copyWith({
    int? finishPosition,
    bool clearFinishPosition = false,
    int? startPosition,
    int? bestLapTimeMs,
    int? averageLapTimeMs,
    double? weight,
    int? kartNumber,
  }) {
    return WeeklyResult(
      weekNumber: weekNumber,
      finishPosition:
          clearFinishPosition ? null : (finishPosition ?? this.finishPosition),
      startPosition: startPosition ?? this.startPosition,
      bestLapTimeMs: bestLapTimeMs ?? this.bestLapTimeMs,
      averageLapTimeMs: averageLapTimeMs ?? this.averageLapTimeMs,
      weight: weight ?? this.weight,
      kartNumber: kartNumber ?? this.kartNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'weekNumber': weekNumber,
        'finishPosition': finishPosition,
        'startPosition': startPosition,
        'bestLapTimeMs': bestLapTimeMs,
        'averageLapTimeMs': averageLapTimeMs,
        'weight': weight,
        'kartNumber': kartNumber,
      };

  factory WeeklyResult.fromJson(Map<String, dynamic> json) {
    return WeeklyResult(
      weekNumber: json['weekNumber'] as int,
      finishPosition: json['finishPosition'] as int?,
      startPosition: json['startPosition'] as int?,
      bestLapTimeMs: json['bestLapTimeMs'] as int?,
      averageLapTimeMs: json['averageLapTimeMs'] as int?,
      weight: (json['weight'] as num?)?.toDouble(),
      kartNumber: json['kartNumber'] as int?,
    );
  }
}
