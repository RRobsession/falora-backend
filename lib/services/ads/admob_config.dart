import 'package:flutter/foundation.dart';

/// AdMob uygulama kimliği (AndroidManifest / Info.plist ile aynı).
const admobAppId = 'ca-app-pub-5266723758630344~8041647287';

/// Release ödüllü reklam birimi.
/// Not: AdMob reklam birimleri `/` ile biter; App ID `~` kullanır.
const releaseRewardedAdUnitId = 'ca-app-pub-5266723758630344/9865864848';

/// Release geçiş reklamı birimi.
const releaseInterstitialAdUnitId = 'ca-app-pub-5266723758630344/8041647287';

// Google resmi test reklam birimleri
const _androidTestRewarded = 'ca-app-pub-3940256099942544/5224354917';
const _androidTestInterstitial = 'ca-app-pub-3940256099942544/1033173712';
const _iosTestRewarded = 'ca-app-pub-3940256099942544/1712485313';
const _iosTestInterstitial = 'ca-app-pub-3940256099942544/4411468910';

String rewardedAdUnitId(TargetPlatform platform) {
  if (kDebugMode) {
    return platform == TargetPlatform.iOS
        ? _iosTestRewarded
        : _androidTestRewarded;
  }
  return releaseRewardedAdUnitId;
}

String interstitialAdUnitId(TargetPlatform platform) {
  if (kDebugMode) {
    return platform == TargetPlatform.iOS
        ? _iosTestInterstitial
        : _androidTestInterstitial;
  }
  return releaseInterstitialAdUnitId;
}

bool get isAdMobSupportedPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
