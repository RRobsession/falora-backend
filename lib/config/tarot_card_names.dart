/// `assets/tarot/` dosya adları (m00, w12, …) → gerçek tarot kart isimleri.
const majorArcanaNamesTr = <String, String>{
  'm00': 'Deli',
  'm01': 'Büyücü',
  'm02': 'Yüksek Rahibe',
  'm03': 'İmparatoriçe',
  'm04': 'İmparator',
  'm05': 'Aziz',
  'm06': 'Aşıklar',
  'm07': 'Savaş Arabası',
  'm08': 'Güç',
  'm09': 'Ermiş',
  'm10': 'Kader Çarkı',
  'm11': 'Adalet',
  'm12': 'Asılmış Adam',
  'm13': 'Ölüm',
  'm14': 'Denge',
  'm15': 'Şeytan',
  'm16': 'Yıkılan Kule',
  'm17': 'Yıldız',
  'm18': 'Ay',
  'm19': 'Güneş',
  'm20': 'Mahkeme',
  'm21': 'Dünya',
};

const _minorSuitNamesTr = <String, String>{
  'w': 'Asa',
  'c': 'Kupa',
  's': 'Kılıç',
  'p': 'Tılsım',
};

const _minorRankNamesTr = <int, String>{
  1: 'Ası',
  2: 'İki',
  3: 'Üç',
  4: 'Dört',
  5: 'Beş',
  6: 'Altı',
  7: 'Yedi',
  8: 'Sekiz',
  9: 'Dokuz',
  10: 'On',
  11: 'Sayfa',
  12: 'Şövalye',
  13: 'Kraliçe',
  14: 'Kral',
};

/// Dosya adından Türkçe tarot kart adı.
String tarotCardNameTr(String id) {
  final trimmed = id.trim().toLowerCase();
  if (trimmed.isEmpty) return id;

  final major = majorArcanaNamesTr[trimmed];
  if (major != null) return major;

  if (trimmed.length < 2) return id;
  final suitCode = trimmed[0];
  final rank = int.tryParse(trimmed.substring(1));
  final suit = _minorSuitNamesTr[suitCode];
  final rankName = rank != null ? _minorRankNamesTr[rank] : null;
  if (suit == null || rankName == null) return id;

  if (rank == 1) return '$suit $rankName';
  if (rank! >= 11) return '$rankName $suit${suffixForCourtCard(suit)}';
  return '$rankName $suit';
}

String suffixForCourtCard(String suit) {
  return switch (suit) {
    'Asa' => 'sı',
    'Kupa' => 'sı',
    'Kılıç' => 'ı',
    'Tılsım' => 'ı',
    _ => 'sı',
  };
}
