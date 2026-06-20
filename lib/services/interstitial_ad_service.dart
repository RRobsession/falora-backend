import 'package:falora/services/ads/ad_config.dart';
import 'package:falora/widgets/mock_ad_overlay.dart';
import 'package:flutter/material.dart';

/// Geçiş reklamı arayüzü. AdMob geçişinde yalnızca implementasyon değişir.
abstract class InterstitialAdService {
  static InterstitialAdService instance = MockInterstitialAdService();

  void recordFortuneSubmission();

  Future<void> maybeShowAfterSubmission(BuildContext context);
}

class MockInterstitialAdService implements InterstitialAdService {
  int _submissionCount = 0;

  @override
  void recordFortuneSubmission() => _submissionCount++;

  @override
  Future<void> maybeShowAfterSubmission(BuildContext context) async {
    if (_submissionCount == 0 ||
        _submissionCount % interstitialAdFrequency != 0) {
      return;
    }
    if (!context.mounted) return;

    await MockAdOverlay.show(
      context,
      title: 'Geçiş Reklamı',
      message: 'Reklam gösteriliyor...',
      closableAfterComplete: true,
    );
  }
}
