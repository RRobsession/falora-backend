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
    productId: 'tokens_100',
    tokens: 100,
    badge: 'En Populer',
    highlight: true,
  ),
  TokenProductDefinition(
    productId: 'tokens_150',
    tokens: 150,
    badge: 'Premium Paket',
  ),
  TokenProductDefinition(
    productId: 'tokens_1500',
    tokens: 1500,
    badge: 'Özel Yorum Paketi',
  ),
];

const tokenProductIds = <String>{
  'tokens_50',
  'tokens_100',
  'tokens_150',
  'tokens_1500',
};

const allBillingProductIds = tokenProductIds;

TokenProductDefinition? tokenProductById(String productId) {
  for (final item in tokenProductCatalog) {
    if (item.productId == productId) return item;
  }
  return null;
}
