import 'package:falora/models/fortune_models.dart';
import 'package:flutter/foundation.dart';

const manualReaderBadgeLabel = 'Özel Yorumcu';
const manualFortuneRightCost = 1;
const manualFortuneRightLabel = 'Özel Fal Hakkı';

/// Serdar / Hatice günlük aktif saatleri (yerel saat).
const manualReaderActiveHoursLabel = 'Her gün 10:30 – 17:00';
const manualReaderActiveStartMinute = 10 * 60 + 30;
const manualReaderActiveEndMinute = 17 * 60;

bool isManualReaderActiveAt(DateTime moment) {
  final minuteOfDay = moment.hour * 60 + moment.minute;
  return minuteOfDay >= manualReaderActiveStartMinute &&
      minuteOfDay <= manualReaderActiveEndMinute;
}

bool get isManualReaderActiveNow => isManualReaderActiveAt(DateTime.now());

String get manualReaderActiveHoursInfo =>
    'Serdar ve Hatice özel yorumcuları $manualReaderActiveHoursLabel arası aktiftir.';

String get manualReaderActiveNowInfo =>
    '$manualReaderActiveHoursInfo Şu an yorum alabilirsiniz.';

String get manualReaderInactiveInfo =>
    '$manualReaderActiveHoursInfo Şu anda aktif değiller; bu saatler dışında talep oluşturulamaz.';

/// Kart üzerinde gösterilen günlük kota (ör. 8/15).
const manualReaderDailyQuotaDisplayMax = 15;

/// Bu sayıya ulaşınca yorumcu o gün kapanır.
const manualReaderDailyQuotaCloseAt = 15;

bool isManualReaderQuotaAvailable(int count) =>
    count < manualReaderDailyQuotaCloseAt;

String manualReaderQuotaLabel(int count) =>
    '$count/$manualReaderDailyQuotaDisplayMax';

String manualReaderQuotaFullInfo(String readerName) =>
    '$readerName bugünkü fal kotasını doldurdu. '
    'Yarın 10:30\'da tekrar açılacak.';

const manualFortuneImagesTooLargeMessage =
    'Fotoğraflar çok büyük. Lütfen daha net veya daha küçük görseller seçip tekrar deneyin.';

/// Fal türüne göre manuel yorum teklifi.
class ManualFortuneOffer {
  const ManualFortuneOffer({
    required this.questionLimit,
    required this.requiresIntention,
  });

  final int questionLimit;
  final bool requiresIntention;

  String get priceLabel => '1 $manualFortuneRightLabel';

  String get questionLabel => '$questionLimit soru hakkı';

  String get intentionLabel =>
      requiresIntention ? 'Niyet gerekli' : 'Niyet eklenebilir';
}

ManualFortuneOffer manualOfferFor(FortuneCategory category) {
  switch (category) {
    case FortuneCategory.tarot:
      return const ManualFortuneOffer(
        questionLimit: 4,
        requiresIntention: false,
      );
    case FortuneCategory.kahve:
    case FortuneCategory.bakla:
    case FortuneCategory.su:
      return const ManualFortuneOffer(
        questionLimit: 2,
        requiresIntention: true,
      );
    case FortuneCategory.iskambil:
      return const ManualFortuneOffer(
        questionLimit: 2,
        requiresIntention: false,
      );
    case FortuneCategory.elFali:
    case FortuneCategory.ciftUyumu:
      throw ArgumentError('Çift uyumu manuel falcı desteklemez');
    case FortuneCategory.ruyaTabiri:
    case FortuneCategory.numeroloji:
    case FortuneCategory.burcYorumu:
    case FortuneCategory.iliskiTavsiyesi:
      throw ArgumentError('Bu kategori manuel falcı desteklemez');
  }
}

void logManualReaderConfig(FortuneCategory category) {
  final offer = manualOfferFor(category);
  debugPrint('MANUAL READER CONFIG LOADED category=${category.name}');
  debugPrint(
    'MANUAL RIGHT COST: ${offer.priceLabel} | questions=${offer.questionLimit}',
  );
  debugPrint('MANUAL QUESTION_LIMIT: ${offer.questionLimit}');
}
