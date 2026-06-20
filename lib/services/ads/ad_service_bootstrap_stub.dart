import 'package:falora/services/interstitial_ad_service.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:flutter/foundation.dart';

/// Web ve AdMob desteklemeyen platformlar için mock reklamlar.
class AdServiceBootstrap {
  static Future<void> init() async {
    RewardedAdService.instance = MockRewardedAdService();
    InterstitialAdService.instance = MockInterstitialAdService();
    debugPrint('MOCK ADS ACTIVE (web/desktop — no AdMob SDK)');
  }
}
