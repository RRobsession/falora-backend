class TokenProductDefinition {
  const TokenProductDefinition({
    required this.productId,
    required this.tokens,
    required this.subtitle,
    this.badge,
    this.highlight = false,
    this.specialFortuneRights = 0,
  });

  final String productId;
  final int tokens;
  final String subtitle;
  final String? badge;
  final bool highlight;
  final int specialFortuneRights;

  bool get isSpecialFortuneProduct => specialFortuneRights > 0;
}

const tokenProductCatalog = <TokenProductDefinition>[
  TokenProductDefinition(
    productId: 'tokens_50',
    tokens: 50,
    subtitle: 'Hızlı Başlangıç',
  ),
  TokenProductDefinition(
    productId: 'tokens_100',
    tokens: 100,
    subtitle: 'Başlangıç Paketi',
  ),
  TokenProductDefinition(
    productId: 'tokens_150',
    tokens: 150,
    subtitle: 'En Popüler',
    badge: 'En Popüler',
    highlight: true,
  ),
  TokenProductDefinition(
    productId: 'tokens_200',
    tokens: 200,
    subtitle: 'Avantajlı Paket',
  ),
  TokenProductDefinition(
    productId: 'tokens_1500',
    tokens: 0,
    specialFortuneRights: 1,
    subtitle: '1 Özel Fal Hakkı',
    badge: 'Premium',
  ),
];

const tokenProductIds = <String>{
  'tokens_50',
  'tokens_100',
  'tokens_150',
  'tokens_200',
  'tokens_1500',
};

const allBillingProductIds = tokenProductIds;

/// Web / geliştirme önizlemesi için sabit fiyatlar (Play Billing yok).
const tokenProductMockPrices = <String, String>{
  'tokens_50': '₺9,94',
  'tokens_100': '₺19,90',
  'tokens_150': '₺29,75',
  'tokens_200': '₺49,93',
  'tokens_1500': '₺349,99',
};

String? mockPriceForProductId(String productId) =>
    tokenProductMockPrices[productId];

TokenProductDefinition? tokenProductById(String productId) {
  for (final item in tokenProductCatalog) {
    if (item.productId == productId) return item;
  }
  return null;
}
