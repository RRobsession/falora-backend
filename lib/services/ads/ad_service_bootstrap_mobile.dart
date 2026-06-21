import 'package:falora/services/ads/admob_config.dart';
import 'package:falora/services/ads/admob_logger.dart';
import 'package:falora/services/admob_interstitial_ad_service.dart';
import 'package:falora/services/admob_rewarded_ad_service.dart';
import 'package:falora/services/interstitial_ad_service.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Android/iOS için gerçek AdMob.
class AdServiceBootstrap {
  static Future<void>? _initFuture;
  static bool initSucceeded = false;

  static Future<void> init() {
    return _initFuture ??= _initImpl();
  }

  static Future<void> ensureInitialized() => init();

  static Future<void> _initImpl() async {
    if (!isAdMobSupportedPlatform) {
      RewardedAdService.instance = MockRewardedAdService();
      InterstitialAdService.instance = MockInterstitialAdService();
      AdMobLogger.log('ADMOB SKIPPED: unsupported platform, using mock ads');
      return;
    }

    AdMobLogger.log('ADMOB INIT START');
    AdMobLogger.log('ADMOB APP ID: $admobAppId');
    AdMobLogger.log(
      'REWARDED AD UNIT ID: ${rewardedAdUnitId(defaultTargetPlatform)}',
    );
    AdMobLogger.log(
      'AD UNIT MODE: ${adUnitModeLabel(defaultTargetPlatform)}',
    );
    AdMobLogger.log('BUILD MODE: ${kDebugMode ? 'debug' : 'release'}');
    AdMobLogger.log('USE_PRODUCTION_ADS: $useProductionAds');

    try {
      final status = await MobileAds.instance.initialize();
      initSucceeded = true;
      AdMobLogger.log('ADMOB INIT SUCCESS');

      status.adapterStatuses.forEach((name, adapterStatus) {
        AdMobLogger.log(
          'ADMOB ADAPTER $name: state=${adapterStatus.state.name} '
          'desc=${adapterStatus.description}',
        );
      });

      final rewarded = AdMobRewardedAdService();
      final interstitial = AdMobInterstitialAdService();
      RewardedAdService.instance = rewarded;
      InterstitialAdService.instance = interstitial;

      rewarded.preload();
      interstitial.preload();
    } catch (e, stackTrace) {
      initSucceeded = false;
      AdMobLogger.log('ADMOB INIT FAILED: $e');
      AdMobLogger.log(stackTrace.toString());

      // Mock'a düşme — gerçek AdMob hatalarını logcat'te görmek için servisi koru.
      final rewarded = AdMobRewardedAdService();
      RewardedAdService.instance = rewarded;
      InterstitialAdService.instance = MockInterstitialAdService();
    }
  }
}
