import 'package:falora/models/fortune_models.dart';

/// Standart AI kategorilerinin 1. seviye ücreti (Rüya/Numeroloji/Burç dahil).
const autoCategoryTokenCost = 50;

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

/// Serdar/Hatice teklif edilmeyen kategoriler.
bool supportsManualFortuneReaders(FortuneCategory category) {
  switch (category) {
    case FortuneCategory.ciftUyumu:
    case FortuneCategory.ruyaTabiri:
    case FortuneCategory.numeroloji:
    case FortuneCategory.burcYorumu:
      return false;
    default:
      return true;
  }
}

/// Rüya, Numeroloji ve Burç — backend otomatik yorum akışı.
bool isAutoOnlyCategory(FortuneCategory category) {
  switch (category) {
    case FortuneCategory.ruyaTabiri:
    case FortuneCategory.numeroloji:
    case FortuneCategory.burcYorumu:
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
    default:
      return category.label;
  }
}
