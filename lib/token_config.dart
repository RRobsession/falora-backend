import 'package:falora/config/play_product_catalog.dart';

/// Başlangıç jeton bakiyesi — `firestore.rules` içindeki `allowedCreateTokenBalance` ile senkron.
const initialUserTokens = 50;
/// Standart falcı 1. seviye (Kahve/Su/İskambil). Tarot 1. seviye: 50 (Gizem Ana).
const fortuneTokenCost = 50;
const coupleTokenCost = 150;
const rewardAdTokenGrant = 25;
const maxRewardedAdsPerDay = 2;
const rewardResetDuration = Duration(hours: 24);
const rewardAdLimitReachedMessage =
    'Bugünkü reklam hakkınızı kullandınız. Yarın tekrar deneyin.';

const shopPackageCatalog = tokenProductCatalog;
