/// Tarot kartı — yalnızca asset dosya adından türetilir (m00, c01, …).
class TarotCardDefinition {
  const TarotCardDefinition({
    required this.id,
    required this.assetPath,
    required this.deckIndex,
  });

  /// Dosya adı uzantısız: `m00`, `c01`, …
  final String id;
  final String assetPath;
  final int deckIndex;

  String get displayLabel => id;
}

/// Kullanıcının seçtiği kart (açılım pozisyonu + ters/düz).
class TarotCardSelection {
  const TarotCardSelection({
    required this.id,
    required this.assetPath,
    required this.positionIndex,
    required this.isReversed,
  });

  final String id;
  final String assetPath;
  final int positionIndex;
  final bool isReversed;

  /// Backend uyumluluğu — anlam çıkarılmaz, dosya adı kullanılır.
  String get nameTr => id;
  String get nameEn => id;
  String get arcana => 'deck';
  String? get suit => null;

  factory TarotCardSelection.fromDefinition(
    TarotCardDefinition definition, {
    required int spreadPosition,
    required bool isReversed,
  }) {
    return TarotCardSelection(
      id: definition.id,
      assetPath: definition.assetPath,
      positionIndex: spreadPosition,
      isReversed: isReversed,
    );
  }

  factory TarotCardSelection.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String? ?? '';
    final storedPath = map['assetPath'] as String?;
    final assetPath = (storedPath != null && storedPath.isNotEmpty)
        ? storedPath
        : (id.isNotEmpty ? tarotAssetPathForId(id) : '');
    return TarotCardSelection(
      id: id,
      assetPath: assetPath,
      positionIndex: (map['positionIndex'] as num?)?.toInt() ?? 0,
      isReversed: map['isReversed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'assetPath': assetPath,
        'nameTr': id,
        'nameEn': id,
        'arcana': arcana,
        'positionIndex': positionIndex,
        'isReversed': isReversed,
      };

  String get displayLabel => isReversed ? '$id · Ters' : id;
}

const tarotSpreadCardCount = 8;
const tarotExpectedDeckSize = 78;

/// Tarot JPG ölçüsü: 350×600 px → genişlik / yükseklik
const double tarotCardAspectRatioFallback = 350 / 600;

/// Geriye dönük uyumluluk — tercihen [TarotDeckService.cardAspectRatio] kullanın.
const double tarotCardAspectRatio = tarotCardAspectRatioFallback;

String tarotAssetPathForId(String id) => 'assets/tarot/$id.jpg';
