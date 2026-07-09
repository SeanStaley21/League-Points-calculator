import 'racer.dart';

class Division {
  final String name;
  final int sortOrder;
  final List<Racer> racers;

  const Division({
    required this.name,
    this.sortOrder = 0,
    this.racers = const [],
  });

  /// The racer currently leading this division by total points, if any.
  Racer? get leader {
    if (racers.isEmpty) return null;
    return racers.reduce((a, b) => a.totalPoints >= b.totalPoints ? a : b);
  }

  Division copyWith({
    String? name,
    int? sortOrder,
    List<Racer>? racers,
  }) {
    return Division(
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      racers: racers ?? this.racers,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sortOrder': sortOrder,
        'racers': racers.map((r) => r.toJson()).toList(),
      };

  factory Division.fromJson(Map<String, dynamic> json) {
    return Division(
      name: json['name'] as String,
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      racers: (json['racers'] as List<dynamic>? ?? [])
          .map((r) => Racer.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
