import 'package:flutter/foundation.dart';

/// AdMob uygulama kimliği (AndroidManifest / Info.plist ile aynı).
const admobAppId = 'ca-app-pub-5266723758630344~8041647287';

/// Release ödüllü reklam birimi.
const releaseRewardedAdUnitId = 'ca-app-pub-5266723758630344/9865864848';

/// Release geçiş reklamı birimi.
const releaseInterstitialAdUnitId = 'ca-app-pub-5266723758630344/8041647287';

// Google resmi test reklam birimleri — yalnızca debug / web / USE_TEST_ADS.
const androidTestRewardedAdUnitId =
    'ca-app-pub-3940256099942544/5224354917';
const androidTestInterstitialAdUnitId =
    'ca-app-pub-3940256099942544/1033173712';
const iosTestRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';
const iosTestInterstitialAdUnitId =
    'ca-app-pub-3940256099942544/4411468910';

/// Release'te bile Google test birimlerini zorla (yalnızca geliştirme).
/// Örnek: --dart-define=USE_TEST_ADS=true
const forceTestAds = bool.fromEnvironment(
  'USE_TEST_ADS',
  defaultValue: false,
);

/// Production'da Google test rewarded ID'sine düşme — kapalı.
/// (Eski --dart-define=REWARD_TEST_FALLBACK artık varsayılan false.)
const rewardTestFallbackOnAccountPending = bool.fromEnvironment(
  'REWARD_TEST_FALLBACK',
  defaultValue: false,
);

/// Release/profile: gerçek AdMob birimleri (dart-define gerekmez).
/// Debug/web veya USE_TEST_ADS=true: Google test birimleri.
bool useTestAdUnits(TargetPlatform platform) {
  if (forceTestAds) return true;
  if (kIsWeb) return true;
  if (kDebugMode) return true;
  // kReleaseMode ve profile: production
  return false;
}

/// Log / geriye uyumluluk: test birimi kullanılmıyorsa production.
bool get useProductionAds =>
    !useTestAdUnits(defaultTargetPlatform);

String rewardedTestAdUnitId(TargetPlatform platform) =>
    platform == TargetPlatform.iOS
        ? iosTestRewardedAdUnitId
        : androidTestRewardedAdUnitId;

String rewardedAdUnitId(TargetPlatform platform) {
  if (useTestAdUnits(platform)) {
    return rewardedTestAdUnitId(platform);
  }
  return releaseRewardedAdUnitId;
}

String interstitialAdUnitId(TargetPlatform platform) {
  if (useTestAdUnits(platform)) {
    return platform == TargetPlatform.iOS
        ? iosTestInterstitialAdUnitId
        : androidTestInterstitialAdUnitId;
  }
  return releaseInterstitialAdUnitId;
}

/// AdMob hesap onayı / envanter yokluğu — production birimde sık görülür.
bool isAdMobAccountOrFillFailure({
  required int code,
  required String message,
}) {
  final m = message.toLowerCase();
  if (m.contains('account not approved') ||
      m.contains('hesabınız onaylanmadı') ||
      m.contains('account is not approved')) {
    return true;
  }
  // 3 = ERROR_CODE_NO_FILL — onay bekleyen hesaplarda da sık gelir.
  if (code == 3) return true;
  return false;
}

String adMobUserFacingLoadError({
  required int code,
  required String message,
}) {
  final m = message.toLowerCase();
  if (m.contains('account not approved') ||
      m.contains('account is not approved')) {
    return 'Reklam hesabı henüz onaylanmadığı için reklam yüklenemedi. '
        'Kısa süre sonra tekrar deneyin.';
  }
  if (code == 3 || m.contains('no fill')) {
    return 'Şu an uygun reklam bulunamadı. Lütfen biraz sonra tekrar deneyin.';
  }
  final detail = message.trim();
  if (detail.isEmpty) {
    return 'Reklam şu anda yüklenemedi, lütfen tekrar deneyin. (kod $code)';
  }
  return 'Reklam şu anda yüklenemedi, lütfen tekrar deneyin. ($code: $detail)';
}

String adUnitModeLabel(TargetPlatform platform) {
  if (useTestAdUnits(platform)) return 'google_test';
  return 'production';
}

bool get isAdMobSupportedPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
