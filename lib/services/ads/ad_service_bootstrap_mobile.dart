import 'package:falora/services/ads/admob_config.dart';
import 'package:falora/services/ads/admob_logger.dart';
import 'package:falora/services/admob_interstitial_ad_service.dart';
import 'package:falora/services/admob_rewarded_ad_service.dart';
import 'package:falora/services/interstitial_ad_service.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

bool get _isMobileAdPlatform =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Android/iOS için gerçek AdMob — mock ödüllü reklam asla kullanılmaz.
class AdServiceBootstrap {
  static Future<void>? _initFuture;
  static bool initSucceeded = false;

  static Future<void> init() {
    return _initFuture ??= _initImpl();
  }

  static Future<void> ensureInitialized() => init();

  static Future<void> _initImpl() async {
    if (!_isMobileAdPlatform) {
      RewardedAdService.instance = UnavailableRewardedAdService();
      InterstitialAdService.instance = MockInterstitialAdService();
      initSucceeded = false;
      AdMobLogger.log(
        'REWARD SERVICE TYPE: ${RewardedAdService.instance.serviceTypeName}',
      );
      AdMobLogger.log('ADMOB SKIPPED: desktop/native-non-mobile platform');
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

    final rewarded = AdMobRewardedAdService();
    RewardedAdService.instance = rewarded;
    AdMobLogger.log('REWARD SERVICE TYPE: ${rewarded.serviceTypeName}');
    AdMobLogger.log('MOCK REWARD USED: no');

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

      final interstitial = AdMobInterstitialAdService();
      InterstitialAdService.instance = interstitial;

      rewarded.preload();
      interstitial.preload();
    } catch (e, stackTrace) {
      initSucceeded = false;
      AdMobLogger.log('ADMOB INIT FAILED: $e');
      AdMobLogger.log(stackTrace.toString());
      InterstitialAdService.instance = MockInterstitialAdService();
      // RewardedAdService.instance AdMobRewardedAdService olarak kalır — mock yok.
    }
  }
}
