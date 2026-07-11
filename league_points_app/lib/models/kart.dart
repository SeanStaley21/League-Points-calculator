/// Which physical kart pool a division draws from. Pro divisions (Pro 1/2/3)
/// share one pool of faster karts; the Juniors division has its own pool of
/// slower karts. Divisions of the same class race at different times, so the
/// same kart number can be picked by one racer per class per week without
/// conflict -- see [Kart].
enum KartClass { pro, junior }

extension KartClassLabel on KartClass {
  String get label => this == KartClass.pro ? 'Pro' : 'Junior';
}

/// One physical kart in the season's pool, identified by its number.
class Kart {
  final int number;
  final KartClass classType;

  /// Week numbers this kart is marked broken/out of service for. A kart can
  /// be down for some weeks and available for others.
  final Set<int> downWeeks;

  const Kart({
    required this.number,
    required this.classType,
    this.downWeeks = const {},
  });

  bool isDownForWeek(int week) => downWeeks.contains(week);

  Kart copyWith({
    int? number,
    KartClass? classType,
    Set<int>? downWeeks,
  }) {
    return Kart(
      number: number ?? this.number,
      classType: classType ?? this.classType,
      downWeeks: downWeeks ?? this.downWeeks,
    );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'classType': classType.name,
        'downWeeks': downWeeks.toList(),
      };

  factory Kart.fromJson(Map<String, dynamic> json) {
    return Kart(
      number: json['number'] as int,
      classType: KartClass.values.byName(json['classType'] as String),
      downWeeks: (json['downWeeks'] as List<dynamic>? ?? const [])
          .map((w) => w as int)
          .toSet(),
    );
  }
}
