import 'package:falora/services/ads/admob_config.dart';
import 'package:falora/services/admob_interstitial_ad_service.dart';
import 'package:falora/services/admob_rewarded_ad_service.dart';
import 'package:falora/services/interstitial_ad_service.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Android/iOS için gerçek AdMob.
class AdServiceBootstrap {
  static Future<void> init() async {
    if (!isAdMobSupportedPlatform) {
      RewardedAdService.instance = MockRewardedAdService();
      InterstitialAdService.instance = MockInterstitialAdService();
      debugPrint('ADMOB SKIPPED: unsupported platform, using mock ads');
      return;
    }

    await MobileAds.instance.initialize();
    debugPrint('ADMOB INITIALIZED');
    debugPrint(
      'AD UNIT ID (rewarded): ${rewardedAdUnitId(defaultTargetPlatform)} '
      '(${kDebugMode ? 'Google test unit' : 'release unit'})',
    );

    final rewarded = AdMobRewardedAdService();
    final interstitial = AdMobInterstitialAdService();
    RewardedAdService.instance = rewarded;
    InterstitialAdService.instance = interstitial;

    rewarded.preload();
    interstitial.preload();
  }
}
