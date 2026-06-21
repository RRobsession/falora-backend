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
  String? _lastErrorMessage;

  @override
  String? get lastErrorMessage => _lastErrorMessage;

  void _logDailyRewardStatus(AppUser user) {
    debugPrint(
      'DAILY_REWARD_STATUS: remaining=${remainingDailyAds(user)} '
      'rewardedAdsToday=${user.rewardedAdsToday} '
      'lastRewardAt=${user.lastRewardAt?.toIso8601String() ?? 'null'}',
    );
  }

  void preload() {
    if (_loading || _rewardedAd != null) return;
    _loading = true;

    final unitId = rewardedAdUnitId(defaultTargetPlatform);
    debugPrint('REWARDED LOAD START');
    debugPrint('REWARDED AD UNIT ID: $unitId (${adUnitModeLabel(defaultTargetPlatform)})');

    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _loading = false;
          _lastErrorMessage = null;
          debugPrint('REWARDED LOAD SUCCESS');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _loading = false;
          _lastErrorMessage =
              'Reklam yüklenemedi (${error.code}): ${error.message}';
          debugPrint('REWARDED LOAD FAILED: ${error.code} ${error.message}');
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
    _logDailyRewardStatus(user);

    if (remainingDailyAds(user) <= 0) {
      _lastErrorMessage = 'Bugünkü ücretsiz jeton hakkını kullandın.';
      debugPrint('REWARDED CLAIM ERROR: daily limit reached');
      return RewardedAdResult.limitReached;
    }

    var ad = _rewardedAd;
    if (ad == null) {
      preload();
      ad = await _waitForAd(const Duration(seconds: 10));
    }
    if (ad == null) {
      _lastErrorMessage ??=
          'Reklam şu an yüklenemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.';
      debugPrint('REWARDED LOAD FAILED: no ad available after wait');
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
        _lastErrorMessage =
            'Reklam gösterilemedi (${error.code}): ${error.message}';
        debugPrint('REWARDED LOAD FAILED: show error ${error.code} ${error.message}');
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );

    try {
      debugPrint('REWARDED SHOW START');
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('REWARDED EARNED: ${reward.amount} ${reward.type}');
          earned = true;
        },
      );
      await dismissed.future;
    } catch (e, stackTrace) {
      _lastErrorMessage = 'Reklam gösterilirken hata oluştu: $e';
      debugPrint('REWARDED LOAD FAILED: show exception $e');
      debugPrint(stackTrace.toString());
      return RewardedAdResult.failed;
    }

    if (showFailed) return RewardedAdResult.failed;
    if (!earned) {
      _lastErrorMessage = 'Reklam tam izlenmedi, jeton verilmedi.';
      return RewardedAdResult.cancelled;
    }

    try {
      debugPrint('REWARDED CLAIM START');
      await TokenService.instance.claimRewardedAd(userId);
      debugPrint('REWARDED CLAIM SUCCESS');
      _lastErrorMessage = null;
      return RewardedAdResult.rewarded;
    } on TokenException catch (e) {
      _lastErrorMessage = e.message;
      debugPrint('REWARDED CLAIM ERROR: ${e.message}');
      return RewardedAdResult.limitReached;
    } catch (e, stackTrace) {
      _lastErrorMessage = 'Jeton eklenemedi: $e';
      debugPrint('REWARDED CLAIM ERROR: $e');
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
