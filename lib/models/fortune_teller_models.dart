import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Yalnızca Tarot Falı falcı tier fiyatları (değiştirilmez).
const premiumTellerTokenCosts = <int>[100, 150, 200];

/// Kahve, Su, İskambil, Bakla ve diğer standart AI fal kategorileri.
const standardTellerTokenCosts = <int>[50, 100, 150];

/// Kullanıcının seçtiği falcı — jeton ücreti ve yorum uzunluğu tier'ına göre değişir.
class FortuneTeller {
  const FortuneTeller({
    required this.id,
    required this.name,
    required this.title,
    required this.bio,
    required this.tokenCost,
    required this.lengthLabel,
    required this.accentColor,
    required this.avatarAsset,
    this.highlight = false,
    this.badge,
  });

  final String id;
  final String name;
  final String title;
  final String bio;
  final int tokenCost;
  final String lengthLabel;
  final Color accentColor;
  final String avatarAsset;
  final bool highlight;
  final String? badge;

  FortuneTeller withTokenCost(int tokenCost) {
    return FortuneTeller(
      id: id,
      name: name,
      title: title,
      bio: bio,
      tokenCost: tokenCost,
      lengthLabel: lengthLabel,
      accentColor: accentColor,
      avatarAsset: avatarAsset,
      highlight: highlight,
      badge: badge,
    );
  }
}

const fortuneTellers = <FortuneTeller>[
  FortuneTeller(
    id: 'gizem_ana',
    name: 'Gizem Ana',
    title: 'Sezgisel Yorumcu',
    bio:
        'Kısa ve öz yorumlarıyla niyetinize odaklanır. Hızlı ama derin bir bakış sunar.',
    tokenCost: 100,
    lengthLabel: 'Kısa yorum · ~300–500 kelime',
    accentColor: Color(0xFF6B4F2A),
    avatarAsset: 'assets/avatars/gizem_ana.png',
  ),
  FortuneTeller(
    id: 'medyum_aylin',
    name: 'Medyum Aylin',
    title: 'Ruhsal Rehber',
    bio:
        'Duygusal katmanları ve sembolleri dengeli şekilde açar. Orta uzunlukta, akıcı bir seans.',
    tokenCost: 150,
    lengthLabel: 'Orta yorum · ~600–900 kelime',
    accentColor: Color(0xFF8B6A3E),
    avatarAsset: 'assets/avatars/medyum_aylin.png',
    highlight: true,
    badge: 'En Popüler',
  ),
  FortuneTeller(
    id: 'ustat_hakan',
    name: 'Üstat Hakan',
    title: 'Kadim Bilge',
    bio:
        'En kapsamlı analiz. Geçmiş, şimdi ve yakın geleceği detaylı bir dille harmanlar.',
    tokenCost: 200,
    lengthLabel: 'Detaylı yorum · ~1000–1500 kelime',
    accentColor: Color(0xFFD4AF37),
    avatarAsset: 'assets/avatars/ustat_hakan.png',
    badge: 'Premium',
  ),
];

/// Rüya Tabiri, Numeroloji ve Burç Yorumu seçim ekranı yorumcuları.
const spiritualFortuneTellers = <FortuneTeller>[
  FortuneTeller(
    id: 'selin',
    name: 'Selin',
    title: 'Rüya & Sembol Uzmanı',
    bio:
        'Rüyaların sembolik dilini sade ve net şekilde açar. Kısa ama derin bir yorum sunar.',
    tokenCost: 50,
    lengthLabel: 'Kısa yorum · ~300–500 kelime',
    accentColor: Color(0xFF5C4A6E),
    avatarAsset: 'assets/avatars/selin.png',
  ),
  FortuneTeller(
    id: 'koray',
    name: 'Koray',
    title: 'Numeroloji Rehberi',
    bio:
        'İsim ve doğum tarihindeki enerjiyi dengeli şekilde yorumlar. Orta uzunlukta, akıcı bir analiz.',
    tokenCost: 100,
    lengthLabel: 'Orta yorum · ~600–900 kelime',
    accentColor: Color(0xFF4A6B7A),
    avatarAsset: 'assets/avatars/koray.png',
    highlight: true,
    badge: 'En Popüler',
  ),
  FortuneTeller(
    id: 'mira',
    name: 'Mira',
    title: 'Kozmik Yorumcu',
    bio:
        'Burç ve ay enerjilerini bir arada okur. En kapsamlı spiritüel analizi sunar.',
    tokenCost: 150,
    lengthLabel: 'Detaylı yorum · ~1000–1500 kelime',
    accentColor: Color(0xFF7A5C3E),
    avatarAsset: 'assets/avatars/mira.png',
    badge: 'Premium',
  ),
];

bool categoryUsesSpiritualTellers(FortuneCategory category) {
  return isAutoOnlyCategory(category);
}

List<FortuneTeller> _baseTellersForCategory(FortuneCategory category) {
  return categoryUsesSpiritualTellers(category)
      ? spiritualFortuneTellers
      : fortuneTellers;
}

bool categoryUsesPremiumTellerPricing(FortuneCategory category) {
  return category == FortuneCategory.tarot;
}

List<int> tellerTokenCostsForCategory(FortuneCategory category) {
  return categoryUsesPremiumTellerPricing(category)
      ? premiumTellerTokenCosts
      : standardTellerTokenCosts;
}

List<FortuneTeller> fortuneTellersForCategory(FortuneCategory category) {
  final costs = tellerTokenCostsForCategory(category);
  final base = _baseTellersForCategory(category);
  return List.generate(base.length, (i) {
    final teller = base[i];
    return teller.withTokenCost(costs[i]);
  });
}

/// Tek kaynak: kategori + falcı kimliğine göre jeton maliyeti.
int resolveTellerTokenCost(FortuneCategory category, String tellerId) {
  if (category == FortuneCategory.iliskiTavsiyesi) {
    return relationshipAdviceTokenCost;
  }
  final tellers = fortuneTellersForCategory(category);
  for (final teller in tellers) {
    if (teller.id == tellerId) {
      return teller.tokenCost;
    }
  }
  return tellers.first.tokenCost;
}

FortuneTeller resolveFortuneTeller(
  FortuneCategory category,
  String tellerId,
) {
  final cost = resolveTellerTokenCost(category, tellerId);
  final tellers = fortuneTellersForCategory(category);
  for (final teller in tellers) {
    if (teller.id == tellerId) {
      return teller.withTokenCost(cost);
    }
  }
  return tellers.first.withTokenCost(
    resolveTellerTokenCost(category, tellers.first.id),
  );
}

void logFortuneSelectedCost(FortuneCategory category, String tellerId) {
  debugPrint(
    'FORTUNE_SELECTED_COST category=${category.name} teller=$tellerId '
    'cost=${resolveTellerTokenCost(category, tellerId)}',
  );
}

void logFortuneVisibleCost(FortuneCategory category, String tellerId) {
  debugPrint(
    'FORTUNE_VISIBLE_COST category=${category.name} teller=$tellerId '
    'cost=${resolveTellerTokenCost(category, tellerId)}',
  );
}

void logFortuneSubmitCost(FortuneCategory category, String tellerId, int cost) {
  debugPrint(
    'FORTUNE_SUBMIT_COST category=${category.name} teller=$tellerId cost=$cost',
  );
}

FortuneTeller? fortuneTellerById(String? id, {FortuneCategory? category}) {
  if (id == null || id.isEmpty) return null;
  final list = category != null
      ? fortuneTellersForCategory(category)
      : [...spiritualFortuneTellers, ...fortuneTellers];
  for (final t in list) {
    if (t.id == id) return t;
  }
  return null;
}
