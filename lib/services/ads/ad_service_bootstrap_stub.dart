import 'package:falora/services/ads/admob_logger.dart';
import 'package:falora/services/interstitial_ad_service.dart';
import 'package:falora/services/rewarded_ad_service.dart';

/// Web ve AdMob desteklemeyen platformlar için mock reklamlar.
class AdServiceBootstrap {
  static Future<void>? _initFuture;
  static bool initSucceeded = false;

  static Future<void> init() {
    return _initFuture ??= _initImpl();
  }

  static Future<void> ensureInitialized() => init();

  static Future<void> _initImpl() async {
    RewardedAdService.instance = MockRewardedAdService();
    InterstitialAdService.instance = MockInterstitialAdService();
    initSucceeded = true;
    AdMobLogger.log('MOCK ADS ACTIVE (web/desktop — no AdMob SDK)');
  }
}
