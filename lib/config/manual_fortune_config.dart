import 'package:falora/models/fortune_models.dart';
import 'package:flutter/foundation.dart';

const manualReaderBadgeLabel = 'Özel Yorumcu';
const manualFortuneTokenCost = 1500;

/// Fal türüne göre manuel yorum teklifi.
class ManualFortuneOffer {
  const ManualFortuneOffer({
    required this.tokenCost,
    required this.questionLimit,
    required this.requiresIntention,
  });

  final int tokenCost;
  final int questionLimit;
  final bool requiresIntention;

  String get priceLabel => '$tokenCost Jeton';

  String get questionLabel => '$questionLimit soru hakkı';

  String get intentionLabel =>
      requiresIntention ? 'Niyet gerekli' : 'Niyet eklenebilir';
}

ManualFortuneOffer manualOfferFor(FortuneCategory category) {
  switch (category) {
    case FortuneCategory.tarot:
      return const ManualFortuneOffer(
        tokenCost: manualFortuneTokenCost,
        questionLimit: 4,
        requiresIntention: false,
      );
    case FortuneCategory.kahve:
    case FortuneCategory.bakla:
    case FortuneCategory.su:
      return const ManualFortuneOffer(
        tokenCost: manualFortuneTokenCost,
        questionLimit: 2,
        requiresIntention: true,
      );
    case FortuneCategory.iskambil:
      return const ManualFortuneOffer(
        tokenCost: manualFortuneTokenCost,
        questionLimit: 2,
        requiresIntention: false,
      );
    case FortuneCategory.ciftUyumu:
      throw ArgumentError('Çift uyumu manuel falcı desteklemez');
  }
}

void logManualReaderConfig(FortuneCategory category) {
  final offer = manualOfferFor(category);
  debugPrint('MANUAL READER CONFIG LOADED category=${category.name}');
  debugPrint(
    'MANUAL TOKEN COST: ${offer.priceLabel} | questions=${offer.questionLimit}',
  );
  debugPrint('MANUAL QUESTION_LIMIT: ${offer.questionLimit}');
}
