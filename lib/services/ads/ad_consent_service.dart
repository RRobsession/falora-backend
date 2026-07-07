import 'dart:async';

import 'package:falora/services/ads/admob_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AB/EEA ve UK kullanıcıları için Google UMP rıza akışı.
class AdConsentService {
  AdConsentService._();

  static Future<void> requestConsentIfNeeded() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      final params = ConsentRequestParameters();
      final completer = Completer<void>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            final available =
                await ConsentInformation.instance.isConsentFormAvailable();
            if (!available) {
              if (!completer.isCompleted) completer.complete();
              return;
            }

            ConsentForm.loadConsentForm(
              (ConsentForm form) async {
                try {
                  final status =
                      await ConsentInformation.instance.getConsentStatus();
                  if (status == ConsentStatus.required) {
                    form.show((_) {
                      if (!completer.isCompleted) completer.complete();
                    });
                  } else if (!completer.isCompleted) {
                    completer.complete();
                  }
                } catch (e) {
                  AdMobLogger.log('AD CONSENT SHOW ERROR: $e');
                  if (!completer.isCompleted) completer.complete();
                }
              },
              (FormError error) {
                AdMobLogger.log('AD CONSENT FORM LOAD ERROR: ${error.message}');
                if (!completer.isCompleted) completer.complete();
              },
            );
          } catch (e) {
            AdMobLogger.log('AD CONSENT CHECK ERROR: $e');
            if (!completer.isCompleted) completer.complete();
          }
        },
        (FormError error) {
          AdMobLogger.log('AD CONSENT INFO ERROR: ${error.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => AdMobLogger.log('AD CONSENT TIMEOUT'),
      );
    } catch (e) {
      AdMobLogger.log('AD CONSENT SKIPPED: $e');
    }
  }
}
