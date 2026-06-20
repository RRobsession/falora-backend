const initialUserTokens = 50;
const fortuneTokenCost = 50;
const coupleTokenCost = 50;
const rewardAdTokenGrant = 50;
const maxRewardedAdsPerDay = 1;
const rewardResetDuration = Duration(hours: 24);

const shopPackages = [50, 100, 150];

class ShopPackageInfo {
  const ShopPackageInfo({
    required this.tokens,
    required this.priceTry,
    this.badge,
    this.highlight = false,
  });

  final int tokens;
  final int priceTry;
  final String? badge;
  final bool highlight;
}

const shopPackageCatalog = [
  ShopPackageInfo(tokens: 50, priceTry: 20),
  ShopPackageInfo(
    tokens: 100,
    priceTry: 30,
    badge: '⭐ En Popüler',
    highlight: true,
  ),
  ShopPackageInfo(
    tokens: 150,
    priceTry: 40,
    badge: '💎 Premium Paket',
  ),
];
