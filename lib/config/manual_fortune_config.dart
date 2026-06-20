import 'package:falora/models/fortune_models.dart';
import 'package:flutter/foundation.dart';

/// Test aşamasında ödeme atlanır; talep doğrudan Firestore'a yazılır.
const manualFortuneSkipBilling = true;

const manualReaderBadgeLabel = 'Özel Yorumcu';

/// Fal türüne göre manuel yorum teklifi.
class ManualFortuneOffer {
  const ManualFortuneOffer({
    required this.priceTRY,
    required this.questionLimit,
    required this.requiresIntention,
  });

  final int priceTRY;
  final int questionLimit;
  final bool requiresIntention;

  String get priceLabel => '$priceTRY TL';

  String get questionLabel =>
      '$questionLimit soru hakkı · Jeton harcanmaz';

  String get intentionLabel =>
      requiresIntention ? 'Niyet gerekli' : 'Niyet eklenebilir';
}

ManualFortuneOffer manualOfferFor(FortuneCategory category) {
  switch (category) {
    case FortuneCategory.tarot:
      return const ManualFortuneOffer(
        priceTRY: 350,
        questionLimit: 4,
        requiresIntention: false,
      );
    case FortuneCategory.kahve:
    case FortuneCategory.bakla:
    case FortuneCategory.su:
      return const ManualFortuneOffer(
        priceTRY: 500,
        questionLimit: 2,
        requiresIntention: true,
      );
    case FortuneCategory.iskambil:
      return const ManualFortuneOffer(
        priceTRY: 250,
        questionLimit: 2,
        requiresIntention: false,
      );
    case FortuneCategory.ciftUyumu:
      throw ArgumentError('Çift uyumu manuel falcı desteklemez');
  }
}

String manualProductId(String readerId, FortuneCategory category) {
  final suffix = switch (category) {
    FortuneCategory.tarot => 'tarot_4q',
    FortuneCategory.kahve => 'coffee_2q',
    FortuneCategory.bakla => 'bakla_2q',
    FortuneCategory.iskambil => 'iskambil_2q',
    FortuneCategory.su => 'su_2q',
    FortuneCategory.ciftUyumu => throw ArgumentError('unsupported'),
  };
  return 'manual_${readerId}_$suffix';
}

const manualFortuneProductIds = <String>{
  'manual_serdar_tarot_4q',
  'manual_hatice_tarot_4q',
  'manual_serdar_coffee_2q',
  'manual_hatice_coffee_2q',
  'manual_serdar_bakla_2q',
  'manual_hatice_bakla_2q',
  'manual_serdar_iskambil_2q',
  'manual_hatice_iskambil_2q',
  'manual_serdar_su_2q',
  'manual_hatice_su_2q',
};

void logManualReaderConfig(FortuneCategory category) {
  final offer = manualOfferFor(category);
  debugPrint('MANUAL READER CONFIG LOADED category=${category.name}');
  debugPrint(
    'MANUAL PRICE SELECTED: ${offer.priceLabel} | questions=${offer.questionLimit}',
  );
  debugPrint('MANUAL QUESTION_LIMIT: ${offer.questionLimit}');
}
