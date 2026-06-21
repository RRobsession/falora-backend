import 'package:falora/models/app_user.dart';
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

    debugPrint('AD SHOW START (mock — web/desktop)');
    final completed = await MockAdOverlay.show(
      context,
      title: 'Ödüllü Reklam',
      message: 'Video izleniyor, lütfen bekleyin...',
      closableAfterComplete: false,
    );

    if (!completed) {
      debugPrint('AD LOAD FAILED: mock ad cancelled before completion');
      return RewardedAdResult.cancelled;
    }

    debugPrint('AD REWARD EARNED (mock — watch completed)');

    try {
      await TokenService.instance.claimRewardedAd(userId);
      debugPrint('AD REWARD GRANTED');
      return RewardedAdResult.rewarded;
    } on TokenException {
      return RewardedAdResult.limitReached;
    } catch (e, stackTrace) {
      debugPrint('AD LOAD FAILED: mock claim error $e');
      debugPrint(stackTrace.toString());
      return RewardedAdResult.failed;
    }
  }
}
