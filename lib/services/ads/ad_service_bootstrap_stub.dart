import 'package:falora/services/ads/admob_logger.dart';
import 'package:falora/services/interstitial_ad_service.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:flutter/foundation.dart';

/// Web (Chrome) — yalnızca geliştirme/test için mock ödüllü reklam.
class AdServiceBootstrap {
  static Future<void>? _initFuture;
  static bool initSucceeded = false;

  static Future<void> init() {
    return _initFuture ??= _initImpl();
  }

  static Future<void> ensureInitialized() => init();

  static Future<void> _initImpl() async {
    assert(kIsWeb, 'Stub bootstrap yalnızca web derlemesinde kullanılmalı.');
    RewardedAdService.instance = MockRewardedAdService();
    InterstitialAdService.instance = MockInterstitialAdService();
    initSucceeded = true;
    AdMobLogger.log(
      'REWARD SERVICE TYPE: ${RewardedAdService.instance.serviceTypeName}',
    );
    AdMobLogger.log('MOCK REWARD USED: allowed (web only)');
    AdMobLogger.log('ADMOB REWARD USED: no');
  }
}
