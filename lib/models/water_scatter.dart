/// Su falı ritüel animasyonunun AI yorumuna aktarılan özeti.
class WaterScatterReading {
  const WaterScatterReading({
    required this.symbols,
    required this.waterClarity,
    required this.rippleCount,
    required this.motion,
    required this.dominantSymbol,
    required this.reflectionStrength,
  });

  final List<String> symbols;
  final String waterClarity;
  final int rippleCount;
  final String motion;
  final String dominantSymbol;
  final String reflectionStrength;

  Map<String, dynamic> toApiMap() => {
        'fortuneType': 'water',
        'symbols': symbols,
        'waterClarity': waterClarity,
        'rippleCount': rippleCount,
        'motion': motion,
        'dominantSymbol': dominantSymbol,
        'reflectionStrength': reflectionStrength,
      };

  factory WaterScatterReading.fromMap(Map<String, dynamic> map) {
    final rawSymbols = map['symbols'];
    final symbols = rawSymbols is List
        ? rawSymbols.map((e) => e.toString()).toList()
        : const <String>[];

    return WaterScatterReading(
      symbols: symbols,
      waterClarity: map['waterClarity'] as String? ?? 'berrak',
      rippleCount: (map['rippleCount'] as num?)?.toInt() ?? 0,
      motion: map['motion'] as String? ?? 'sakin',
      dominantSymbol: map['dominantSymbol'] as String? ?? '',
      reflectionStrength: map['reflectionStrength'] as String? ?? 'orta',
    );
  }

  static String motionForRippleCount(int count) {
    if (count <= 2) return 'sakin';
    if (count <= 4) return 'orta';
    return 'hareketli';
  }
}
