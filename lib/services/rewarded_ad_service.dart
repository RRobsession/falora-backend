import 'package:falora/models/app_user.dart';
import 'package:falora/services/ads/admob_logger.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/token_config.dart';
import 'package:falora/widgets/mock_ad_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum RewardedAdResult {
  rewarded,
  limitReached,
  cancelled,
  failed,
}

const rewardedAdLoadFailedMessage =
    'Reklam şu anda yüklenemedi, lütfen tekrar deneyin.';

/// Ödüllü reklam arayüzü.
abstract class RewardedAdService {
  /// Bootstrap tamamlanana kadar güvenli varsayılan — ödül vermez.
  static RewardedAdService instance = UnavailableRewardedAdService();

  /// Son reklam/jeton hatası.
  String? get lastErrorMessage;

  /// Teşhis logları için servis adı.
  String get serviceTypeName;

  bool hasDailyRewardAvailable(AppUser user);

  int remainingDailyAds(AppUser user);

  String? dailyLimitMessage(AppUser user);

  Future<RewardedAdResult> watchAndClaim({
    required BuildContext context,
    required String userId,
    required AppUser user,
  });
}

/// Android/iOS dışı native platformlar veya AdMob kullanılamayan durumlar.
class UnavailableRewardedAdService implements RewardedAdService {
  String? _lastErrorMessage;

  @override
  String? get lastErrorMessage => _lastErrorMessage;

  @override
  String get serviceTypeName => 'UnavailableRewardedAdService';

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
    AdMobLogger.log('REWARD SERVICE TYPE: $serviceTypeName');
    AdMobLogger.log('MOCK REWARD USED: no');
    AdMobLogger.log('ADMOB REWARD USED: no');
    _lastErrorMessage = rewardedAdLoadFailedMessage;
    AdMobLogger.log('REWARDED LOAD FAILED: ads unavailable on this platform');
    return RewardedAdResult.failed;
  }
}

/// Yalnızca Web (Chrome) geliştirme/test için sahte ödüllü reklam.
class MockRewardedAdService implements RewardedAdService {
  @override
  String? get lastErrorMessage => null;

  @override
  String get serviceTypeName => 'MockRewardedAdService';

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
    AdMobLogger.log('REWARD SERVICE TYPE: $serviceTypeName');

    if (!kIsWeb) {
      AdMobLogger.log('MOCK REWARD USED: no (blocked on native platform)');
      AdMobLogger.log('ADMOB REWARD USED: no');
      AdMobLogger.log(
        'REWARDED LOAD FAILED: mock blocked — native requires AdMob',
      );
      return RewardedAdResult.failed;
    }

    if (remainingDailyAds(user) <= 0) {
      AdMobLogger.log('REWARDED_CLAIM_LIMIT_REACHED');
      return RewardedAdResult.limitReached;
    }

    AdMobLogger.log('DAILY_REWARD_LIMIT=$maxRewardedAdsPerDay');
    AdMobLogger.log('REWARDED_CLAIM_ATTEMPT uid=$userId');

    AdMobLogger.log('MOCK REWARD USED: yes (web only)');
    AdMobLogger.log('ADMOB REWARD USED: no');
    AdMobLogger.log('REWARDED SHOW START (mock web)');

    final completed = await MockAdOverlay.show(
      context,
      title: 'Ödüllü Reklam',
      message: 'Reklamı izleyerek jeton kazanabilirsiniz.',
      closableAfterComplete: false,
    );

    if (!completed) {
      AdMobLogger.log('REWARDED LOAD FAILED: mock ad cancelled');
      return RewardedAdResult.cancelled;
    }

    AdMobLogger.log('REWARDED EARNED (mock web)');

    try {
      await TokenService.instance.claimRewardedAd(userId);
      AdMobLogger.log('REWARDED_CLAIM_SUCCESS');
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
