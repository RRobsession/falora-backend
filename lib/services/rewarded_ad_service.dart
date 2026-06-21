import 'package:falora/models/app_user.dart';
import 'package:falora/services/ads/admob_logger.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/widgets/mock_ad_overlay.dart';
import 'package:flutter/material.dart';

enum RewardedAdResult {
  rewarded,
  limitReached,
  cancelled,
  failed,
}

/// Ödüllü reklam arayüzü. AdMob geçişinde yalnızca implementasyon değişir.
abstract class RewardedAdService {
  static RewardedAdService instance = MockRewardedAdService();

  /// Son reklam/jeton hatası (AdMob implementasyonunda doldurulur).
  String? get lastErrorMessage => null;

  bool hasDailyRewardAvailable(AppUser user);

  int remainingDailyAds(AppUser user);

  String? dailyLimitMessage(AppUser user);

  Future<RewardedAdResult> watchAndClaim({
    required BuildContext context,
    required String userId,
    required AppUser user,
  });
}

class MockRewardedAdService implements RewardedAdService {
  @override
  String? get lastErrorMessage => null;

  @override
  bool hasDailyRewardAvailable(AppUser user) =>
      TokenService.instance.remainingRewardAds(user) > 0;

  @override
  int remainingDailyAds(AppUser user) =>
      TokenService.instance.remainingRewardAds(user);

  @override
  String? dailyLimitMessage(AppUser user) {
    if (remainingDailyAds(user) > 0) return null;
    return TokenService.instance.rewardAdWaitMessage(user);
  }

  @override
  Future<RewardedAdResult> watchAndClaim({
    required BuildContext context,
    required String userId,
    required AppUser user,
  }) async {
    if (remainingDailyAds(user) <= 0) {
      return RewardedAdResult.limitReached;
    }

    AdMobLogger.log('REWARDED SHOW START (mock — web/desktop)');
    final completed = await MockAdOverlay.show(
      context,
      title: 'Ödüllü Reklam',
      message: 'Video izleniyor, lütfen bekleyin...',
      closableAfterComplete: false,
    );

    if (!completed) {
      AdMobLogger.log('REWARDED LOAD FAILED: mock ad cancelled');
      return RewardedAdResult.cancelled;
    }

    AdMobLogger.log('REWARDED EARNED (mock)');

    try {
      AdMobLogger.log('REWARDED CLAIM START');
      await TokenService.instance.claimRewardedAd(userId);
      AdMobLogger.log('REWARDED CLAIM SUCCESS');
      return RewardedAdResult.rewarded;
    } on TokenException catch (e) {
      AdMobLogger.claimError(e.message);
      return RewardedAdResult.limitReached;
    } catch (e, stackTrace) {
      AdMobLogger.claimError(e, stackTrace);
      return RewardedAdResult.failed;
    }
  }
}
