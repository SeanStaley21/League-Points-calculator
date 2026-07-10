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

  WeeklyResult copyWith({
    int? finishPosition,
    bool clearFinishPosition = false,
    int? startPosition,
    int? bestLapTimeMs,
    int? averageLapTimeMs,
    double? weight,
    bool clearWeight = false,
    int? kartNumber,
  }) {
    return WeeklyResult(
      weekNumber: weekNumber,
      finishPosition:
          clearFinishPosition ? null : (finishPosition ?? this.finishPosition),
      startPosition: startPosition ?? this.startPosition,
      bestLapTimeMs: bestLapTimeMs ?? this.bestLapTimeMs,
      averageLapTimeMs: averageLapTimeMs ?? this.averageLapTimeMs,
      weight: clearWeight ? null : (weight ?? this.weight),
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
