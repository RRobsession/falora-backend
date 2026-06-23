import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/services/ads/ad_service_bootstrap.dart';
import 'package:falora/services/ads/admob_config.dart';
import 'package:falora/services/ads/admob_logger.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/token_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobRewardedAdService implements RewardedAdService {
  RewardedAd? _rewardedAd;
  bool _loading = false;
  String? _lastErrorMessage;
  int _loadAttempt = 0;

  @override
  String get serviceTypeName => 'AdMobRewardedAdService';

  @override
  String? get lastErrorMessage => _lastErrorMessage;

  void _logDailyRewardStatus(AppUser user) {
    AdMobLogger.log(
      'DAILY_REWARD_STATUS: remaining=${remainingDailyAds(user)} '
      'rewardedAdsToday=${user.rewardedAdsToday} '
      'lastRewardAt=${user.lastRewardAt?.toIso8601String() ?? 'null'}',
    );
  }

  void preload() {
    if (_loading || _rewardedAd != null) return;
    _loading = true;
    _loadAttempt++;

    final unitId = rewardedAdUnitId(defaultTargetPlatform);
    AdMobLogger.log('REWARDED LOAD START');
    AdMobLogger.log('REWARDED AD UNIT ID: $unitId');

    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _loading = false;
          _lastErrorMessage = null;
          AdMobLogger.log('REWARDED LOAD SUCCESS');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _loading = false;
          _lastErrorMessage = rewardedAdLoadFailedMessage;
          AdMobLogger.rewardedLoadFailed(error);
          _scheduleRetry();
        },
      ),
    );
  }

  void _scheduleRetry() {
    if (_loadAttempt >= 4) return;
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (_rewardedAd == null && !_loading) {
        preload();
      }
    });
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
    await AdServiceBootstrap.ensureInitialized();
    AdMobLogger.log('REWARD SERVICE TYPE: $serviceTypeName');
    AdMobLogger.log('MOCK REWARD USED: no');
    AdMobLogger.log('ADMOB REWARD USED: yes');
    AdMobLogger.log('DAILY_REWARD_LIMIT=$maxRewardedAdsPerDay');
    _logDailyRewardStatus(user);

    if (!AdServiceBootstrap.initSucceeded) {
      _lastErrorMessage = rewardedAdLoadFailedMessage;
      AdMobLogger.log('REWARDED LOAD FAILED: AdMob init not successful');
      return RewardedAdResult.failed;
    }

    if (remainingDailyAds(user) <= 0) {
      _lastErrorMessage = rewardAdLimitReachedMessage;
      AdMobLogger.log('REWARDED_CLAIM_LIMIT_REACHED');
      return RewardedAdResult.limitReached;
    }

    AdMobLogger.log('REWARDED_CLAIM_ATTEMPT uid=$userId');

    var ad = _rewardedAd;
    if (ad == null) {
      preload();
      ad = await _waitForAd(const Duration(seconds: 15));
    }
    if (ad == null) {
      _lastErrorMessage ??= rewardedAdLoadFailedMessage;
      AdMobLogger.log('REWARDED LOAD FAILED: no ad available after wait');
      return RewardedAdResult.failed;
    }

    final rewardEarned = Completer<bool>();
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
        _lastErrorMessage = rewardedAdLoadFailedMessage;
        AdMobLogger.rewardedShowFailed(error);
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );

    try {
      AdMobLogger.log('REWARDED SHOW START');
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          AdMobLogger.log('REWARDED EARNED');
          AdMobLogger.log(
            'REWARDED EARNED DETAIL: amount=${reward.amount} type=${reward.type}',
          );
          if (!rewardEarned.isCompleted) {
            rewardEarned.complete(true);
          }
        },
      );
      await dismissed.future;
    } catch (e, stackTrace) {
      _lastErrorMessage = rewardedAdLoadFailedMessage;
      AdMobLogger.log('REWARDED SHOW FAILED exception: $e');
      AdMobLogger.log(stackTrace.toString());
      return RewardedAdResult.failed;
    }

    if (showFailed) return RewardedAdResult.failed;

    final earned = await rewardEarned.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => false,
    );
    if (!earned) {
      _lastErrorMessage = 'Reklam tam izlenmedi, jeton verilmedi.';
      AdMobLogger.log('REWARDED CLAIM ERROR: reward callback not received');
      return RewardedAdResult.cancelled;
    }

    try {
      await TokenService.instance.claimRewardedAd(userId);
      AdMobLogger.log('REWARDED_CLAIM_SUCCESS');
      _lastErrorMessage = null;
      return RewardedAdResult.rewarded;
    } on TokenException catch (e) {
      _lastErrorMessage = e.message;
      AdMobLogger.claimError(e.message);
      return RewardedAdResult.limitReached;
    } on FirebaseException catch (e) {
      _lastErrorMessage = 'Jeton yazılamadı (${e.code}): ${e.message}';
      AdMobLogger.claimError('Firebase ${e.code}: ${e.message}');
      return RewardedAdResult.failed;
    } catch (e, stackTrace) {
      _lastErrorMessage = 'Jeton eklenemedi: $e';
      AdMobLogger.claimError(e, stackTrace);
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
