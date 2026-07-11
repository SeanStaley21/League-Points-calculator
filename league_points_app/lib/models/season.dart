import 'division.dart';
import 'kart.dart';

class Season {
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final int weekCount;
  // How many finish positions score points (e.g. 13 means 1st..13th score,
  // 14th+ scores 0). Editable so a division that grows past the table's
  // range can still score everyone. See points_calculator.dart.
  final int scoredPositions;
  final List<Division> divisions;

  /// Season-wide pool of physical karts (see [Kart]), shared by all
  /// divisions of the same [KartClass] for Kart Pick Order.
  final List<Kart> kartPool;

  const Season({
    required this.name,
    required this.startDate,
    this.endDate,
    required this.weekCount,
    required this.scoredPositions,
    this.divisions = const [],
    this.kartPool = const [],
  });

  factory Season.blankTemplate({required int weekCount, required int scoredPositions}) {
    return Season(
      name: 'New Season',
      startDate: DateTime.now(),
      weekCount: weekCount,
      scoredPositions: scoredPositions,
      divisions: const [],
    );
  }

  Season copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? weekCount,
    int? scoredPositions,
    List<Division>? divisions,
    List<Kart>? kartPool,
  }) {
    return Season(
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      weekCount: weekCount ?? this.weekCount,
      scoredPositions: scoredPositions ?? this.scoredPositions,
      divisions: divisions ?? this.divisions,
      kartPool: kartPool ?? this.kartPool,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'weekCount': weekCount,
        'scoredPositions': scoredPositions,
        'divisions': divisions.map((d) => d.toJson()).toList(),
        'kartPool': kartPool.map((k) => k.toJson()).toList(),
      };

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      name: json['name'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      weekCount: json['weekCount'] as int,
      scoredPositions: (json['scoredPositions'] as int?) ?? 13,
      divisions: (json['divisions'] as List<dynamic>? ?? [])
          .map((d) => Division.fromJson(d as Map<String, dynamic>))
          .toList(),
      kartPool: (json['kartPool'] as List<dynamic>? ?? [])
          .map((k) => Kart.fromJson(k as Map<String, dynamic>))
          .toList(),
    );
  }
}
