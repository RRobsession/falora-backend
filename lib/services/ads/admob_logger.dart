import 'dart:developer' as developer;

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Release build'de de logcat'te görünür AdMob teşhis logları.
abstract final class AdMobLogger {
  static void log(String message) {
    developer.log(message, name: 'FALORA_ADMOB');
    // ignore: avoid_print
    print(message);
  }

  static void rewardedLoadFailed(LoadAdError error) {
    log(
      'REWARDED LOAD FAILED '
      'code=${error.code} '
      'message=${error.message} '
      'domain=${error.domain}',
    );
  }

  static void rewardedShowFailed(AdError error) {
    log(
      'REWARDED SHOW FAILED '
      'code=${error.code} '
      'message=${error.message} '
      'domain=${error.domain}',
    );
  }

  static void claimError(Object error, [StackTrace? stackTrace]) {
    log('REWARDED CLAIM ERROR: $error');
    if (stackTrace != null) {
      log(stackTrace.toString());
    }
  }
}
