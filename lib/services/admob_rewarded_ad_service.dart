import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/services/ads/ad_consent_service.dart';
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
  String? _lastErrorMessage;
  String? _loadedUnitId;

  /// Tek aktif RewardedAd.load() — preload ve kullanıcı bekleyişi paylaşır.
  Future<RewardedAd?>? _inFlightLoad;
  int _loadGeneration = 0;

  Timer? _retryTimer;
  int _retryIndex = 0;

  static const _retryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];
  static const _steadyRetryDelay = Duration(seconds: 30);

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

  String get _preferredUnitId => rewardedAdUnitId(defaultTargetPlatform);

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Açılış / show sonrası / arka plan retry — yeni load yalnızca boşta iken.
  void preload() {
    if (_rewardedAd != null) {
      AdMobLogger.log('REWARDED PRELOAD SKIP: ad already ready');
      return;
    }
    if (_inFlightLoad != null) {
      AdMobLogger.log('REWARDED PRELOAD SKIP: load already in flight');
      return;
    }
    unawaited(_beginLoad(reason: 'preload'));
  }

  /// Kullanıcı butona bastığında: mevcut in-flight varsa onu bekler (yeni request yok).
  Future<RewardedAd?> _awaitReady({required Duration timeout}) async {
    if (_rewardedAd != null) return _rewardedAd;

    if (_inFlightLoad != null) {
      AdMobLogger.log(
        'REWARDED WAIT EXISTING IN-FLIGHT (no new AdMob request)',
      );
      try {
        await _inFlightLoad!.timeout(timeout);
      } on TimeoutException {
        _lastErrorMessage ??=
            'Reklam zaman aşımına uğradı, lütfen tekrar deneyin.';
        AdMobLogger.log(
          'REWARDED WAIT TIMEOUT — in-flight continues; '
          'late ad will be kept in cache or disposed if superseded',
        );
      }
      return _rewardedAd;
    }

    // Anlık ihtiyaç: bekleyen retry cooldown'unu bekleme; hemen yükle.
    // Başarılı yükleme gelene kadar arka plan retry sayacı korunur.
    _cancelRetry();
    final future = _beginLoad(reason: 'user_request');
    try {
      await future.timeout(timeout);
    } on TimeoutException {
      _lastErrorMessage ??=
          'Reklam zaman aşımına uğradı, lütfen tekrar deneyin.';
      AdMobLogger.log(
        'REWARDED USER LOAD TIMEOUT — in-flight continues; '
        'late success caches ad for next use',
      );
    }
    return _rewardedAd;
  }

  Future<RewardedAd?> _beginLoad({required String reason}) {
    if (_rewardedAd != null) return Future<RewardedAd?>.value(_rewardedAd);
    final existing = _inFlightLoad;
    if (existing != null) return existing;

    final unitId = _preferredUnitId;
    final generation = ++_loadGeneration;
    final completer = Completer<RewardedAd?>();
    final future = completer.future;
    _inFlightLoad = future;

    AdMobLogger.log('REWARDED LOAD START reason=$reason generation=$generation');
    AdMobLogger.log('REWARDED AD UNIT ID: $unitId');
    AdMobLogger.log(
      'AD UNIT MODE: ${adUnitModeLabel(defaultTargetPlatform)} '
      'useProductionAds=$useProductionAds '
      'rewardTestFallback=$rewardTestFallbackOnAccountPending',
    );

    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (generation != _loadGeneration) {
            AdMobLogger.log(
              'REWARDED LATE LOAD DISPOSE superseded gen=$generation '
              'current=$_loadGeneration',
            );
            ad.dispose();
            if (!completer.isCompleted) completer.complete(null);
            return;
          }

          _rewardedAd = ad;
          _loadedUnitId = unitId;
          _lastErrorMessage = null;
          _retryIndex = 0;
          _cancelRetry();
          AdMobLogger.log('REWARDED LOAD SUCCESS unit=$unitId reason=$reason');
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          if (generation != _loadGeneration) {
            if (!completer.isCompleted) completer.complete(null);
            return;
          }

          _rewardedAd = null;
          _loadedUnitId = null;
          _lastErrorMessage = adMobUserFacingLoadError(
            code: error.code,
            message: error.message,
          );
          AdMobLogger.rewardedLoadFailed(error);
          AdMobLogger.log(
            'REWARDED LOAD FAILED DETAIL shown_to_user=$_lastErrorMessage '
            'unit=$unitId mode=${adUnitModeLabel(defaultTargetPlatform)} '
            'useProductionAds=$useProductionAds reason=$reason',
          );
          if (!completer.isCompleted) completer.complete(null);
          _scheduleRetry();
        },
      ),
    );

    future.whenComplete(() {
      if (identical(_inFlightLoad, future)) {
        _inFlightLoad = null;
      }
    });

    return future;
  }

  void _scheduleRetry() {
    if (_rewardedAd != null || _inFlightLoad != null) return;

    final Duration delay;
    if (_retryIndex < _retryDelays.length) {
      delay = _retryDelays[_retryIndex];
    } else {
      // Üçüncü (30s) denemeden sonra uygulama açıkken 30s aralıkla devam.
      delay = _steadyRetryDelay;
    }
    final attempt = _retryIndex + 1;
    _retryIndex++;
    _cancelRetry();
    AdMobLogger.log(
      'REWARDED RETRY SCHEDULED attempt=$attempt '
      'delay=${delay.inSeconds}s '
      'steady=${_retryIndex > _retryDelays.length}',
    );
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_rewardedAd != null || _inFlightLoad != null) return;
      preload();
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

  Future<RewardedAdResult> _claimTokens(
    String userId, {
    required bool withoutAd,
    String? reason,
  }) async {
    try {
      await TokenService.instance.claimRewardedAd(userId);
      if (withoutAd) {
        _lastErrorMessage = rewardGrantedWithoutAdMessage;
        AdMobLogger.log(
          'REWARDED_CLAIM_SUCCESS_WITHOUT_AD reason=${reason ?? '-'}',
        );
      } else {
        _lastErrorMessage = null;
        AdMobLogger.log('REWARDED_CLAIM_SUCCESS');
      }
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

  Future<RewardedAdResult> _grantDespiteAdFailure(
    String userId,
    String reason,
  ) {
    if (!grantRewardWhenAdUnavailable) {
      return Future.value(RewardedAdResult.failed);
    }
    AdMobLogger.log('REWARDED GRACE GRANT reason=$reason');
    return _claimTokens(userId, withoutAd: true, reason: reason);
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
    AdMobLogger.log(
      'REWARD_GRACE_WHEN_AD_UNAVAILABLE=$grantRewardWhenAdUnavailable',
    );
    _logDailyRewardStatus(user);

    if (remainingDailyAds(user) <= 0) {
      _lastErrorMessage = rewardAdLimitReachedMessage;
      AdMobLogger.log('REWARDED_CLAIM_LIMIT_REACHED');
      return RewardedAdResult.limitReached;
    }

    if (!AdServiceBootstrap.initSucceeded) {
      AdMobLogger.log('REWARDED LOAD FAILED: AdMob init not successful');
      final grace = await _grantDespiteAdFailure(userId, 'admob_init_failed');
      if (grace == RewardedAdResult.rewarded) return grace;
      _lastErrorMessage = rewardedAdLoadFailedMessage;
      return RewardedAdResult.failed;
    }

    if (AdConsentService.lastCanRequestAds == false) {
      AdMobLogger.log('REWARDED LOAD FAILED: canRequestAds=false');
      final grace = await _grantDespiteAdFailure(userId, 'consent_denied');
      if (grace == RewardedAdResult.rewarded) return grace;
      _lastErrorMessage =
          'Reklam izni verilmedi. Ayarlardan reklam rızasını güncelleyip tekrar deneyin.';
      return RewardedAdResult.failed;
    }

    AdMobLogger.log('REWARDED_CLAIM_ATTEMPT uid=$userId');
    AdMobLogger.log(
      'REWARDED UNIT preferred=$_preferredUnitId '
      'loaded=${_loadedUnitId ?? '-'} '
      'mode=${adUnitModeLabel(defaultTargetPlatform)} '
      'useProductionAds=$useProductionAds '
      'inFlight=${_inFlightLoad != null}',
    );

    final loadTimeout = grantRewardWhenAdUnavailable
        ? const Duration(seconds: 4)
        : const Duration(seconds: 12);

    final ad = _rewardedAd ?? await _awaitReady(timeout: loadTimeout);
    if (ad == null) {
      AdMobLogger.log(
        'REWARDED LOAD FAILED: no ad available '
        'lastError=$_lastErrorMessage '
        '(no test-unit fallback)',
      );
      final grace = await _grantDespiteAdFailure(userId, 'no_fill');
      if (grace == RewardedAdResult.rewarded) return grace;
      _lastErrorMessage ??=
          '$rewardedAdLoadFailedMessage (hazır reklam yok / no-fill)';
      return RewardedAdResult.failed;
    }

    final rewardEarned = Completer<bool>();
    var showFailed = false;
    final dismissed = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadedUnitId = null;
        _retryIndex = 0;
        preload();
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadedUnitId = null;
        _retryIndex = 0;
        preload();
        showFailed = true;
        _lastErrorMessage = adMobUserFacingLoadError(
          code: error.code,
          message: error.message,
        );
        AdMobLogger.rewardedShowFailed(error);
        if (!rewardEarned.isCompleted) rewardEarned.complete(false);
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );

    try {
      AdMobLogger.log('REWARDED SHOW START unit=${_loadedUnitId ?? '?'}');
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
      AdMobLogger.log('REWARDED SHOW FAILED exception: $e');
      AdMobLogger.log(stackTrace.toString());
      final grace = await _grantDespiteAdFailure(userId, 'show_exception');
      if (grace == RewardedAdResult.rewarded) return grace;
      _lastErrorMessage = rewardedAdLoadFailedMessage;
      return RewardedAdResult.failed;
    }

    if (showFailed) {
      final grace = await _grantDespiteAdFailure(userId, 'show_failed');
      if (grace == RewardedAdResult.rewarded) return grace;
      return RewardedAdResult.failed;
    }

    final earned = await rewardEarned.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => false,
    );
    if (!earned) {
      _lastErrorMessage = 'Reklam tam izlenmedi, jeton verilmedi.';
      AdMobLogger.log('REWARDED CLAIM ERROR: reward callback not received');
      return RewardedAdResult.cancelled;
    }

    return _claimTokens(userId, withoutAd: false);
  }
}
