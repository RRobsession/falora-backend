import 'dart:async';

import 'package:falora/services/ads/ad_config.dart';
import 'package:falora/services/ads/admob_config.dart';
import 'package:falora/services/interstitial_ad_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobInterstitialAdService implements InterstitialAdService {
  InterstitialAd? _interstitialAd;
  bool _loading = false;
  int _submissionCount = 0;

  void preload() {
    if (_loading || _interstitialAd != null) return;
    _loading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId(defaultTargetPlatform),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _loading = false;
          debugPrint('INTERSTITIAL LOADED');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _loading = false;
          debugPrint('INTERSTITIAL LOAD FAILED: ${error.message}');
        },
      ),
    );
  }

  @override
  void recordFortuneSubmission() => _submissionCount++;

  @override
  Future<void> maybeShowAfterSubmission(BuildContext context) async {
    if (_submissionCount == 0 ||
        _submissionCount % interstitialAdFrequency != 0) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint('INTERSTITIAL SKIP: not loaded');
      preload();
      return;
    }

    if (!context.mounted) return;

    final dismissed = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        preload();
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        preload();
        debugPrint('INTERSTITIAL SHOW FAILED: ${error.message}');
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );

    try {
      debugPrint('INTERSTITIAL SHOWN');
      await ad.show();
      await dismissed.future;
    } catch (e) {
      debugPrint('INTERSTITIAL SHOW ERROR: $e');
      _interstitialAd?.dispose();
      _interstitialAd = null;
      preload();
    }
  }
}
