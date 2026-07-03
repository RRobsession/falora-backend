/// İskambil kartı Türkçe isimleri ve 7'li açılım pozisyonları.

const playingSpreadCardCount = 7;
const playingExpectedDeckSize = 52;
const double playingCardAspectRatio = 0.7142857; // width / height, örn. 2.5 / 3.5

const playingSpreadPositionLabels = [
  'Temel',
  'Geçmiş',
  'Şimdi',
  'Yakın gelecek',
  'Engel',
  'Tavsiye',
  'Sonuç',
];

String playingSuitTr(String suitCode) {
  return switch (suitCode) {
    'h' => 'Kupa',
    'd' => 'Karo',
    'c' => 'Sinek',
    's' => 'Maça',
    _ => suitCode,
  };
}

String playingRankTr(String rankCode) {
  return switch (rankCode) {
    'a' => 'As',
    'j' => 'Vale',
    'q' => 'Kız',
    'k' => 'Kral',
    _ => rankCode,
  };
}

String playingCardNameTr(String id) {
  final parts = id.split('_');
  if (parts.length != 2) return id;
  final suit = playingSuitTr(parts[0]);
  final rank = playingRankTr(parts[1]);
  return '$suit $rank';
}

String playingSpreadPositionLabel(int positionIndex) {
  final index = positionIndex - 1;
  if (index < 0 || index >= playingSpreadPositionLabels.length) {
    return 'Pozisyon $positionIndex';
  }
  return playingSpreadPositionLabels[index];
}
