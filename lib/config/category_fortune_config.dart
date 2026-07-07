import 'package:falora/models/fortune_models.dart';

/// Standart AI kategorilerinin 1. seviye ücreti (Rüya/Numeroloji/Burç dahil).
const autoCategoryTokenCost = 50;

/// İlişki Tavsiyesi — sabit ücret.
const relationshipAdviceTokenCost = 100;

const partnerGenderOptions = ['Kadın', 'Erkek'];

const horoscopeFocusAreas = ['Genel', 'Aşk', 'Para', 'Kariyer'];

const dreamTypes = ['Genel', 'Aşk', 'Kariyer', 'Para', 'Aile'];

const numerologyAnalysisTypes = [
  'Hayat Yolu',
  'Aşk Uyumu',
  'Kariyer Potansiyeli',
  'Genel Analiz',
];

/// UI etiketi → backend `focusArea` değeri.
const horoscopeFocusUiOptions = <String, String>{
  '❤️ Aşk': 'Aşk',
  '💰 Para': 'Para',
  '💼 Kariyer': 'Kariyer',
  '🌟 Genel': 'Genel',
};

class HomeCategorySection {
  const HomeCategorySection({
    required this.title,
    required this.categories,
  });

  final String title;
  final List<FortuneCategory> categories;
}

const homeCategorySections = <HomeCategorySection>[
  HomeCategorySection(
    title: 'Fallar',
    categories: [
      FortuneCategory.tarot,
      FortuneCategory.bakla,
      FortuneCategory.kahve,
      FortuneCategory.su,
      FortuneCategory.iskambil,
    ],
  ),
  HomeCategorySection(
    title: 'Spiritüel Analizler',
    categories: [
      FortuneCategory.burcYorumu,
      FortuneCategory.numeroloji,
      FortuneCategory.ruyaTabiri,
    ],
  ),
  HomeCategorySection(
    title: 'İlişkiler',
    categories: [
      FortuneCategory.ciftUyumu,
      FortuneCategory.iliskiTavsiyesi,
    ],
  ),
];

/// Serdar/Hatice yalnızca tarot, bakla ve kahve falında sunulur.
bool supportsManualFortuneReaders(FortuneCategory category) {
  switch (category) {
    case FortuneCategory.tarot:
    case FortuneCategory.bakla:
    case FortuneCategory.kahve:
      return true;
    default:
      return false;
  }
}

/// Rüya, Numeroloji ve Burç — backend otomatik yorum akışı.
bool isAutoOnlyCategory(FortuneCategory category) {
  switch (category) {
    case FortuneCategory.ruyaTabiri:
    case FortuneCategory.numeroloji:
    case FortuneCategory.burcYorumu:
    case FortuneCategory.iliskiTavsiyesi:
      return true;
    default:
      return false;
  }
}

/// Eski düz ücret fallback'i (yeni istekler falcı seçiminden gelir).
int tokenCostForCategory(FortuneCategory category) {
  return autoCategoryTokenCost;
}

/// Backend `categoryType` değeri.
String backendCategoryType(FortuneCategory category) {
  switch (category) {
    case FortuneCategory.ruyaTabiri:
      return 'dream_interpretation';
    case FortuneCategory.numeroloji:
      return 'numerology';
    case FortuneCategory.burcYorumu:
      return 'horoscope';
    case FortuneCategory.iliskiTavsiyesi:
      return 'relationship_advice';
    default:
      throw ArgumentError('Otomatik kategori değil: $category');
  }
}

String categoryFortuneTitle(FortuneCategory category) {
  switch (category) {
    case FortuneCategory.ruyaTabiri:
      return 'Rüya Tabiri';
    case FortuneCategory.numeroloji:
      return 'Numeroloji Yorumu';
    case FortuneCategory.burcYorumu:
      return 'Burç Yorumu';
    case FortuneCategory.iliskiTavsiyesi:
      return 'İlişki Tavsiyesi';
    default:
      return category.label;
  }
}

String formatBirthDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String summarizeDreamText(String dreamText, {int maxLength = 120}) {
  final trimmed = dreamText.trim();
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength).trim()}…';
}

String buildCategorySummary(
  FortuneCategory category,
  Map<String, dynamic> inputData,
) {
  switch (category) {
    case FortuneCategory.ruyaTabiri:
      final dream = inputData['dreamText'] as String? ?? '';
      return 'Rüya: ${summarizeDreamText(dream)}';
    case FortuneCategory.numeroloji:
      final name = inputData['name'] as String? ?? '';
      final birthDate = inputData['birthDate'] as String? ?? '';
      return 'İsim: $name\nDoğum tarihi: $birthDate';
    case FortuneCategory.burcYorumu:
      final sun = inputData['sunSign'] as String? ?? '';
      final moon = inputData['moonSign'] as String? ?? '';
      final focus = inputData['focusArea'] as String? ?? '';
      return 'Güneş: $sun · Ay: $moon\nOdak: $focus';
    case FortuneCategory.iliskiTavsiyesi:
      final name = inputData['partnerName'] as String? ?? '';
      final gender = inputData['partnerGender'] as String? ?? '';
      final zodiac = inputData['partnerZodiac'] as String? ?? '';
      final age = inputData['partnerAge'] as String? ?? '';
      final problem = inputData['problemText'] as String? ?? '';
      return 'Karşı taraf: $name ($gender, $age, $zodiac)\n'
          'Sorun: ${summarizeDreamText(problem, maxLength: 100)}';
    default:
      return category.label;
  }
}
