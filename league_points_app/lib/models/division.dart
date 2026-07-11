import 'kart.dart';
import 'racer.dart';

class Division {
  final String name;
  final int sortOrder;
  final List<Racer> racers;

  /// Which kart pool (see [Kart]) this division draws from for Kart Pick
  /// Order. Defaults to pro since most divisions are pro divisions.
  final KartClass kartClass;

  const Division({
    required this.name,
    this.sortOrder = 0,
    this.racers = const [],
    this.kartClass = KartClass.pro,
  });

  /// The racer currently leading this division by total points, if any.
  Racer? leader(int scoredPositions) {
    if (racers.isEmpty) return null;
    return racers.reduce((a, b) =>
        a.totalPoints(scoredPositions) >= b.totalPoints(scoredPositions) ? a : b);
  }

  Division copyWith({
    String? name,
    int? sortOrder,
    List<Racer>? racers,
    KartClass? kartClass,
  }) {
    return Division(
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      racers: racers ?? this.racers,
      kartClass: kartClass ?? this.kartClass,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sortOrder': sortOrder,
        'racers': racers.map((r) => r.toJson()).toList(),
        'kartClass': kartClass.name,
      };

  factory Division.fromJson(Map<String, dynamic> json) {
    return Division(
      name: json['name'] as String,
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      racers: (json['racers'] as List<dynamic>? ?? [])
          .map((r) => Racer.fromJson(r as Map<String, dynamic>))
          .toList(),
      kartClass: json['kartClass'] != null
          ? KartClass.values.byName(json['kartClass'] as String)
          : KartClass.pro,
    );
  }
}
