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

    debugPrint('ADMOB INIT START');
    debugPrint('ADMOB APP ID: $admobAppId');
    debugPrint(
      'REWARDED AD UNIT ID: ${rewardedAdUnitId(defaultTargetPlatform)} '
      '(${adUnitModeLabel(defaultTargetPlatform)})',
    );
    debugPrint('BUILD MODE: ${kDebugMode ? 'debug' : 'release'}');
    debugPrint('USE_PRODUCTION_ADS: $useProductionAds');

    try {
      await MobileAds.instance.initialize();
      debugPrint('ADMOB INIT SUCCESS');

      final rewarded = AdMobRewardedAdService();
      final interstitial = AdMobInterstitialAdService();
      RewardedAdService.instance = rewarded;
      InterstitialAdService.instance = interstitial;

      rewarded.preload();
      interstitial.preload();
    } catch (e, stackTrace) {
      debugPrint('ADMOB INIT FAILED: $e');
      debugPrint(stackTrace.toString());
      RewardedAdService.instance = MockRewardedAdService();
      InterstitialAdService.instance = MockInterstitialAdService();
    }
  }
}
