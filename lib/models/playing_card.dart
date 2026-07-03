import 'package:falora/config/playing_card_names.dart';

enum PlayingSuit { hearts, diamonds, clubs, spades }

class PlayingCardDefinition {
  const PlayingCardDefinition({
    required this.id,
    required this.suit,
    required this.rank,
    required this.assetPath,
    required this.deckIndex,
  });

  final String id;
  final PlayingSuit suit;
  final String rank;
  final String assetPath;
  final int deckIndex;

  String get displayLabel => playingCardNameTr(id);

  bool get isRed =>
      suit == PlayingSuit.hearts || suit == PlayingSuit.diamonds;
}

class PlayingCardSelection {
  const PlayingCardSelection({
    required this.id,
    required this.suit,
    required this.rank,
    required this.assetPath,
    required this.positionIndex,
    required this.isReversed,
  });

  final String id;
  final String suit;
  final String rank;
  final String assetPath;
  final int positionIndex;
  final bool isReversed;

  String get nameTr => playingCardNameTr(id);
  String get positionLabel => playingSpreadPositionLabel(positionIndex);

  factory PlayingCardSelection.fromDefinition(
    PlayingCardDefinition definition, {
    required int spreadPosition,
    required bool isReversed,
  }) {
    return PlayingCardSelection(
      id: definition.id,
      suit: definition.id.split('_').first,
      rank: definition.id.split('_').last,
      assetPath: definition.assetPath,
      positionIndex: spreadPosition,
      isReversed: isReversed,
    );
  }

  factory PlayingCardSelection.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String? ?? '';
    final parts = id.contains('_') ? id.split('_') : ['', ''];
    final storedPath = map['assetPath'] as String?;
    final assetPath = (storedPath != null && storedPath.isNotEmpty)
        ? storedPath
        : (id.isNotEmpty ? playingAssetPathForId(id) : '');
    return PlayingCardSelection(
      id: id,
      suit: map['suit'] as String? ?? parts[0],
      rank: map['rank'] as String? ?? parts[1],
      assetPath: assetPath,
      positionIndex: (map['positionIndex'] as num?)?.toInt() ?? 0,
      isReversed: map['isReversed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'suit': suit,
        'rank': rank,
        'assetPath': assetPath,
        'nameTr': nameTr,
        'deckType': 'playing',
        'positionIndex': positionIndex,
        'positionLabel': positionLabel,
        'isReversed': isReversed,
      };

  Map<String, dynamic> toApiMap() => {
        'id': nameTr,
        'nameTr': nameTr,
        'suit': playingSuitTr(suit),
        'rank': playingRankTr(rank),
        'deckType': 'playing',
        'positionIndex': positionIndex,
        'positionLabel': positionLabel,
        'isReversed': isReversed,
      };

  String get displayLabel =>
      isReversed ? '$nameTr · Ters' : nameTr;
}

String playingAssetPathForId(String id) => 'assets/playing_cards/$id.svg';
