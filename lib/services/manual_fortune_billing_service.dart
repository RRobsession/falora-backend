import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:falora/services/play_billing_service.dart';

class ManualFortunePurchaseResult {
  const ManualFortunePurchaseResult({
    required this.success,
    this.purchaseToken,
    this.errorMessage,
  });

  final bool success;
  final String? purchaseToken;
  final String? errorMessage;
}

class ManualFortuneBillingService {
  ManualFortuneBillingService._();

  static final ManualFortuneBillingService instance =
      ManualFortuneBillingService._();

  Future<void> init() => PlayBillingService.instance.init();

  Future<void> dispose() => PlayBillingService.instance.dispose();

  Future<ManualFortunePurchaseResult> purchase(String productId) async {
    try {
      if (kIsWeb) {
        return const ManualFortunePurchaseResult(
          success: false,
          errorMessage: 'Özel falcı yorumu yalnızca mobil uygulamada satın alınabilir.',
        );
      }
      final purchase = await PlayBillingService.instance.buyConsumable(productId);
      return ManualFortunePurchaseResult(
        success: true,
        purchaseToken: purchase.purchaseToken,
      );
    } on PlayBillingException catch (e) {
      return ManualFortunePurchaseResult(
        success: false,
        errorMessage: e.message,
      );
    }
  }
}
