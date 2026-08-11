import 'package:falora/config/play_product_catalog.dart';

/// Başlangıç jeton bakiyesi — `firestore.rules` içindeki `allowedCreateTokenBalance` ile senkron.
const initialUserTokens = 50;
/// Standart falcı 1. seviye (Kahve/Su/İskambil). Tarot 1. seviye: 50 (Gizem Ana).
const fortuneTokenCost = 50;
const coupleTokenCost = 150;
const rewardAdTokenGrant = 25;
const maxRewardedAdsPerDay = 6;
const rewardResetDuration = Duration(hours: 24);
const rewardAdLimitReachedMessage =
    'Bugünkü reklam hakkınızı kullandınız. Yarın tekrar deneyin.';

/// AdMob hesabı onaylanana kadar: reklam yüklenmese/açılmasa da
/// günlük hak içinde butona basınca jeton verilir.
/// Onay sonrası false yapın.
const grantRewardWhenAdUnavailable = true;

const rewardGrantedWithoutAdMessage =
    'Reklam şu an gösterilemedi; günlük ödülünüz hesabınıza eklendi.';

const shopPackageCatalog = tokenProductCatalog;
