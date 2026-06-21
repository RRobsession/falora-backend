import 'package:falora/models/fortune_models.dart';

enum BillingProductKind { manualFortune, tokenPack }

class TokenProductDefinition {
  const TokenProductDefinition({
    required this.productId,
    required this.tokens,
    this.badge,
    this.highlight = false,
  });

  final String productId;
  final int tokens;
  final String? badge;
  final bool highlight;
}

const tokenProductCatalog = <TokenProductDefinition>[
  TokenProductDefinition(productId: 'tokens_50', tokens: 50),
  TokenProductDefinition(
    productId: 'tokens_150',
    tokens: 150,
    badge: 'En Populer',
    highlight: true,
  ),
  TokenProductDefinition(productId: 'tokens_300', tokens: 300),
  TokenProductDefinition(
    productId: 'tokens_750',
    tokens: 750,
    badge: 'Avantajli Paket',
  ),
  TokenProductDefinition(
    productId: 'tokens_1500',
    tokens: 1500,
    badge: 'Premium Paket',
  ),
];

const tokenProductIds = <String>{
  'tokens_50',
  'tokens_150',
  'tokens_300',
  'tokens_750',
  'tokens_1500',
};

const manualFortuneProductIds = <String>{
  'serdar_tarot_4q_350',
  'hatice_tarot_4q_350',
  'serdar_kahve_2q_500',
  'hatice_kahve_2q_500',
  'serdar_bakla_2q_500',
  'hatice_bakla_2q_500',
  'serdar_su_2q_500',
  'hatice_su_2q_500',
  'serdar_iskambil_2q_250',
  'hatice_iskambil_2q_250',
};

const allBillingProductIds = <String>{
  ...manualFortuneProductIds,
  ...tokenProductIds,
};

String manualProductId(String readerId, FortuneCategory category) {
  final type = switch (category) {
    FortuneCategory.tarot => 'tarot_4q_350',
    FortuneCategory.kahve => 'kahve_2q_500',
    FortuneCategory.bakla => 'bakla_2q_500',
    FortuneCategory.su => 'su_2q_500',
    FortuneCategory.iskambil => 'iskambil_2q_250',
    FortuneCategory.ciftUyumu => throw ArgumentError('unsupported'),
  };
  return '${readerId}_$type';
}

TokenProductDefinition? tokenProductById(String productId) {
  for (final item in tokenProductCatalog) {
    if (item.productId == productId) return item;
  }
  return null;
}
