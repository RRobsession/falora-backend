class TokenProductDefinition {
  const TokenProductDefinition({
    required this.productId,
    required this.tokens,
    required this.subtitle,
    this.badge,
    this.highlight = false,
  });

  final String productId;
  final int tokens;
  final String subtitle;
  final String? badge;
  final bool highlight;
}

const tokenProductCatalog = <TokenProductDefinition>[
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
    tokens: 1500,
    subtitle: 'Özel Yorum Paketi',
    badge: 'Premium',
  ),
];

const tokenProductIds = <String>{
  'tokens_100',
  'tokens_150',
  'tokens_200',
  'tokens_1500',
};

const allBillingProductIds = tokenProductIds;

/// Web / geliştirme önizlemesi için sabit fiyatlar (Play Billing yok).
const tokenProductMockPrices = <String, String>{
  'tokens_100': '₺95,99',
  'tokens_150': '₺119,99',
  'tokens_200': '₺159,99',
  'tokens_1500': '₺499,99',
};

String? mockPriceForProductId(String productId) =>
    tokenProductMockPrices[productId];

TokenProductDefinition? tokenProductById(String productId) {
  for (final item in tokenProductCatalog) {
    if (item.productId == productId) return item;
  }
  return null;
}
