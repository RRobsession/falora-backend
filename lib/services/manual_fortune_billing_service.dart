import 'dart:async';

import 'package:falora/config/manual_fortune_config.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Completer<ManualFortunePurchaseResult>? _pendingPurchase;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _purchaseSub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        _pendingPurchase?.complete(
          ManualFortunePurchaseResult(
            success: false,
            errorMessage: 'Ödeme hatası: $e',
          ),
        );
        _pendingPurchase = null;
      },
    );
    _initialized = true;
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _initialized = false;
  }

  Future<ManualFortunePurchaseResult> purchase(String productId) async {
    if (manualFortuneSkipBilling) {
      return ManualFortunePurchaseResult(
        success: true,
        purchaseToken: 'skip_billing_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    if (kIsWeb) {
      return const ManualFortunePurchaseResult(
        success: false,
        errorMessage: 'Özel falcı yorumu yalnızca mobil uygulamada satın alınabilir.',
      );
    }

    if (kDebugMode) {
      return ManualFortunePurchaseResult(
        success: true,
        purchaseToken: 'debug_manual_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    await init();

    final available = await _iap.isAvailable();
    if (!available) {
      return const ManualFortunePurchaseResult(
        success: false,
        errorMessage: 'Google Play ödeme servisi kullanılamıyor.',
      );
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      return ManualFortunePurchaseResult(
        success: false,
        errorMessage: response.error!.message,
      );
    }
    if (response.productDetails.isEmpty) {
      return const ManualFortunePurchaseResult(
        success: false,
        errorMessage: 'Ürün bulunamadı. Play Console yapılandırmasını kontrol edin.',
      );
    }

    final product = response.productDetails.first;
    final completer = Completer<ManualFortunePurchaseResult>();
    _pendingPurchase = completer;

    final started = await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      _pendingPurchase = null;
      return const ManualFortunePurchaseResult(
        success: false,
        errorMessage: 'Ödeme başlatılamadı.',
      );
    }

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pendingPurchase = null;
        return const ManualFortunePurchaseResult(
          success: false,
          errorMessage: 'Ödeme zaman aşımına uğradı.',
        );
      },
    );
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!manualFortuneProductIds.contains(purchase.productID)) continue;

      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _completePending(
          ManualFortunePurchaseResult(
            success: false,
            errorMessage: purchase.error?.message ?? 'Ödeme başarısız.',
          ),
        );
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        _completePending(
          const ManualFortunePurchaseResult(
            success: false,
            errorMessage: 'Ödeme iptal edildi.',
          ),
        );
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final token = purchase.verificationData.serverVerificationData;
        if (token.isEmpty) {
          _completePending(
            const ManualFortunePurchaseResult(
              success: false,
              errorMessage: 'Geçersiz satın alma doğrulaması.',
            ),
          );
        } else {
          _completePending(
            ManualFortunePurchaseResult(success: true, purchaseToken: token),
          );
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  void _completePending(ManualFortunePurchaseResult result) {
    final pending = _pendingPurchase;
    if (pending != null && !pending.isCompleted) {
      pending.complete(result);
    }
    _pendingPurchase = null;
  }
}
