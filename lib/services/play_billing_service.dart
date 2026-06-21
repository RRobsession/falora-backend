import 'dart:async';

import 'package:falora/config/play_product_catalog.dart';
import 'package:falora/services/fortune_submit_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum PurchaseSource { purchased, restored }

class PlayPurchaseResult {
  const PlayPurchaseResult({
    required this.productId,
    required this.purchaseToken,
    required this.source,
    this.purchaseId,
    this.transactionDate,
  });

  final String productId;
  final String purchaseToken;
  final String? purchaseId;
  final String? transactionDate;
  final PurchaseSource source;
}

class PlayBillingException implements Exception {
  PlayBillingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlayBillingService {
  PlayBillingService._();

  static final PlayBillingService instance = PlayBillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, Completer<PlayPurchaseResult>> _purchaseCompleters = {};
  final List<PlayPurchaseResult> _restoredPurchases = [];
  Completer<List<PlayPurchaseResult>>? _restoreCompleter;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _purchaseSub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        final message = 'Odeme akisi hatasi: $e';
        for (final completer in _purchaseCompleters.values) {
          if (!completer.isCompleted) {
            completer.completeError(PlayBillingException(message));
          }
        }
        _purchaseCompleters.clear();
        _completeRestore();
      },
    );
    _initialized = true;
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _initialized = false;
  }

  Future<List<ProductDetails>> queryProducts(Set<String> productIds) async {
    if (kIsWeb) return const [];
    await init();
    final available = await _iap.isAvailable();
    if (!available) {
      throw PlayBillingException(
        'Google Play odeme servisi kullanilamiyor. Cihazin Play Store ile giris yaptigindan emin olun.',
      );
    }

    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('PLAY BILLING query error: ${response.error!.message}');
      throw PlayBillingException(tokenBillingProductsNotReadyMessage);
    }

    return response.productDetails;
  }

  Future<PlayPurchaseResult> buyConsumable(String productId) async {
    if (kIsWeb) {
      throw PlayBillingException(
        'Google Play Billing yalnizca Android uygulamasinda kullanilabilir.',
      );
    }

    await init();
    final products = await queryProducts({productId});
    if (products.isEmpty) {
      debugPrint(
        'PLAY BILLING: product not found in Play Console productId=$productId',
      );
      throw PlayBillingException(tokenBillingProductsNotReadyMessage);
    }

    if (_purchaseCompleters.containsKey(productId)) {
      throw PlayBillingException('Bu urun icin zaten bekleyen bir satin alma var.');
    }

    final completer = Completer<PlayPurchaseResult>();
    _purchaseCompleters[productId] = completer;

    final started = await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: products.first),
    );

    if (!started) {
      _purchaseCompleters.remove(productId);
      throw PlayBillingException('Odeme baslatilamadi.');
    }

    return completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        _purchaseCompleters.remove(productId);
        throw PlayBillingException(
          'Satin alma islemi zaman asimina ugradi. Google Play penceresini kapattiysaniz tekrar deneyin.',
        );
      },
    );
  }

  Future<List<PlayPurchaseResult>> restorePurchases() async {
    if (kIsWeb) return const [];
    await init();

    _restoredPurchases.clear();
    _restoreCompleter = Completer<List<PlayPurchaseResult>>();
    await _iap.restorePurchases();

    return _restoreCompleter!.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => _completeRestore(),
    );
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!allBillingProductIds.contains(purchase.productID)) continue;

      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _completePurchaseError(
          purchase.productID,
          purchase.error?.message.isNotEmpty == true
              ? purchase.error!.message
              : 'Odeme basarisiz oldu.',
        );
        await _completePlayPurchaseIfNeeded(purchase);
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        _completePurchaseError(purchase.productID, 'Odeme iptal edildi.');
        await _completePlayPurchaseIfNeeded(purchase);
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final token = purchase.verificationData.serverVerificationData.trim();
        if (token.isEmpty) {
          _completePurchaseError(
            purchase.productID,
            'Play satin alma dogrulamasi alinmadi.',
          );
          await _completePlayPurchaseIfNeeded(purchase);
          continue;
        }

        final result = PlayPurchaseResult(
          productId: purchase.productID,
          purchaseToken: token,
          purchaseId: purchase.purchaseID,
          transactionDate: purchase.transactionDate,
          source: purchase.status == PurchaseStatus.restored
              ? PurchaseSource.restored
              : PurchaseSource.purchased,
        );

        final completer = _purchaseCompleters.remove(purchase.productID);
        if (completer != null && !completer.isCompleted) {
          completer.complete(result);
        }

        if (purchase.status == PurchaseStatus.restored) {
          _restoredPurchases.add(result);
        }

        await _completePlayPurchaseIfNeeded(purchase);
      }
    }

    if (_restoreCompleter != null && _restoredPurchases.isNotEmpty) {
      _completeRestore();
    }
  }

  void _completePurchaseError(String productId, String message) {
    final completer = _purchaseCompleters.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(PlayBillingException(message));
    }
  }

  Future<void> _completePlayPurchaseIfNeeded(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  List<PlayPurchaseResult> _completeRestore() {
    final restored = List<PlayPurchaseResult>.from(_restoredPurchases);
    final completer = _restoreCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(restored);
    }
    _restoreCompleter = null;
    _restoredPurchases.clear();
    return restored;
  }
}
