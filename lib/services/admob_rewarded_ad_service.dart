import 'dart:async';

import 'package:falora/models/app_user.dart';
import 'package:falora/services/ads/admob_config.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobRewardedAdService implements RewardedAdService {
  RewardedAd? _rewardedAd;
  bool _loading = false;

  void preload() {
    if (_loading || _rewardedAd != null) return;
    _loading = true;

    final unitId = rewardedAdUnitId(defaultTargetPlatform);
    debugPrint('AD LOAD START');
    debugPrint('AD UNIT ID: $unitId (debug=${kDebugMode ? 'test' : 'release'})');

    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _loading = false;
          debugPrint('AD LOAD SUCCESS');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _loading = false;
          debugPrint('AD LOAD FAILED: ${error.code} ${error.message}');
        },
      ),
    );
  }

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

    var ad = _rewardedAd;
    if (ad == null) {
      preload();
      ad = await _waitForAd(const Duration(seconds: 8));
    }
    if (ad == null) {
      debugPrint('AD LOAD FAILED: no ad available after wait');
      return RewardedAdResult.failed;
    }

    var earned = false;
    var showFailed = false;
    final dismissed = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        preload();
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        preload();
        showFailed = true;
        debugPrint('AD LOAD FAILED: show error ${error.code} ${error.message}');
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );

    try {
      debugPrint('AD SHOW START');
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('AD REWARD EARNED: ${reward.amount} ${reward.type}');
          earned = true;
        },
      );
      await dismissed.future;
    } catch (e, stackTrace) {
      debugPrint('AD LOAD FAILED: show exception $e');
      debugPrint(stackTrace.toString());
      return RewardedAdResult.failed;
    }

    if (showFailed) return RewardedAdResult.failed;
    if (!earned) return RewardedAdResult.cancelled;

    try {
      await TokenService.instance.claimRewardedAd(userId);
      debugPrint('AD REWARD GRANTED');
      return RewardedAdResult.rewarded;
    } on TokenException {
      return RewardedAdResult.limitReached;
    } catch (e, stackTrace) {
      debugPrint('AD LOAD FAILED: claim error $e');
      debugPrint(stackTrace.toString());
      return RewardedAdResult.failed;
    }
  }

  Future<RewardedAd?> _waitForAd(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_rewardedAd != null) return _rewardedAd;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return _rewardedAd;
  }
}
