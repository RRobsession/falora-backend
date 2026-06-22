import 'package:falora/models/fortune_models.dart';
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
  return List.generate(fortuneTellers.length, (i) {
    final teller = fortuneTellers[i];
    return FortuneTeller(
      id: teller.id,
      name: teller.name,
      title: teller.title,
      bio: teller.bio,
      tokenCost: costs[i],
      lengthLabel: teller.lengthLabel,
      accentColor: teller.accentColor,
      avatarAsset: teller.avatarAsset,
      highlight: teller.highlight,
      badge: teller.badge,
    );
  });
}

FortuneTeller? fortuneTellerById(String? id, {FortuneCategory? category}) {
  if (id == null || id.isEmpty) return null;
  final list = category != null
      ? fortuneTellersForCategory(category)
      : fortuneTellers;
  for (final t in list) {
    if (t.id == id) return t;
  }
  return null;
}
