import 'package:flutter/foundation.dart';

/// AdMob uygulama kimliği (AndroidManifest / Info.plist ile aynı).
const admobAppId = 'ca-app-pub-5266723758630344~8041647287';

/// Release ödüllü reklam birimi.
const releaseRewardedAdUnitId = 'ca-app-pub-5266723758630344/9865864848';

/// Release geçiş reklamı birimi.
const releaseInterstitialAdUnitId = 'ca-app-pub-5266723758630344/8041647287';

// Google resmi test reklam birimleri
const androidTestRewardedAdUnitId =
    'ca-app-pub-3940256099942544/5224354917';
const androidTestInterstitialAdUnitId =
    'ca-app-pub-3940256099942544/1033173712';
const iosTestRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';
const iosTestInterstitialAdUnitId =
    'ca-app-pub-3940256099942544/4411468910';

/// Gerçek AdMob birimleri (--dart-define=USE_PRODUCTION_ADS=true).
/// Kapalı test / release varsayılanı: Google test reklam birimleri.
const useProductionAds = bool.fromEnvironment(
  'USE_PRODUCTION_ADS',
  defaultValue: false,
);

bool useTestAdUnits(TargetPlatform platform) {
  if (kIsWeb) return true;
  if (kDebugMode) return true;
  return !useProductionAds;
}

String rewardedAdUnitId(TargetPlatform platform) {
  if (useTestAdUnits(platform)) {
    return platform == TargetPlatform.iOS
        ? iosTestRewardedAdUnitId
        : androidTestRewardedAdUnitId;
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

String adUnitModeLabel(TargetPlatform platform) {
  if (useTestAdUnits(platform)) return 'google_test';
  return 'production';
}

bool get isAdMobSupportedPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
