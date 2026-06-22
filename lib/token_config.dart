import 'package:falora/config/play_product_catalog.dart';

/// Başlangıç jeton bakiyesi — `firestore.rules` içindeki `allowedCreateTokenBalance` ile senkron.
const initialUserTokens = 50;
/// Standart falcı 1. seviye (Kahve/Su/İskambil). Premium: 100 (Tarot/Bakla).
const fortuneTokenCost = 50;
/// Çift Uyumu düz ücret — değiştirilmedi.
const coupleTokenCost = 100;
const rewardAdTokenGrant = 50;
const maxRewardedAdsPerDay = 2;
const rewardResetDuration = Duration(hours: 24);
const rewardAdLimitReachedMessage =
    'Bugünkü reklam hakkınızı kullandınız. Yarın tekrar deneyin.';

const shopPackageCatalog = tokenProductCatalog;
