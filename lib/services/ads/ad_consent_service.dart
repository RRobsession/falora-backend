import 'dart:async';

import 'package:falora/services/ads/admob_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AB/EEA ve UK kullanıcıları için Google UMP rıza akışı.
class AdConsentService {
  AdConsentService._();

  static bool? lastCanRequestAds;
  static bool privacyOptionsRequired = false;

  static Future<void> requestConsentIfNeeded() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      final params = ConsentRequestParameters();
      final updateDone = Completer<void>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          if (!updateDone.isCompleted) updateDone.complete();
        },
        (FormError error) {
          AdMobLogger.log('AD CONSENT INFO ERROR: ${error.message}');
          if (!updateDone.isCompleted) updateDone.complete();
        },
      );

      await updateDone.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => AdMobLogger.log('AD CONSENT INFO TIMEOUT'),
      );

      privacyOptionsRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;

      final formDone = Completer<void>();
      await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
        if (formError != null) {
          AdMobLogger.log(
            'AD CONSENT FORM ERROR: ${formError.errorCode} ${formError.message}',
          );
        }
        if (!formDone.isCompleted) formDone.complete();
      });
      await formDone.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => AdMobLogger.log('AD CONSENT FORM TIMEOUT'),
      );

      lastCanRequestAds = await ConsentInformation.instance.canRequestAds();
      final status = await ConsentInformation.instance.getConsentStatus();
      AdMobLogger.log(
        'AD CONSENT STATUS: $status canRequestAds=$lastCanRequestAds '
        'privacyOptionsRequired=$privacyOptionsRequired',
      );
    } catch (e) {
      AdMobLogger.log('AD CONSENT SKIPPED: $e');
      lastCanRequestAds = null;
    }
  }

  static Future<String?> showPrivacyOptions() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return 'Reklam gizlilik tercihleri bu cihazda kullanılamıyor.';
    }

    final done = Completer<String?>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) {
        AdMobLogger.log(
          'AD PRIVACY OPTIONS ERROR: ${error.errorCode} ${error.message}',
        );
      }
      if (!done.isCompleted) done.complete(error?.message);
    });
    return done.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => 'Gizlilik seçenekleri zaman aşımına uğradı.',
    );
  }
}
