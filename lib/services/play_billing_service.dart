import 'dart:async';

import 'package:falora/config/play_product_catalog.dart';
import 'package:falora/services/fortune_submit_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  PlayBillingException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Kullanıcı Google Play ödeme ekranını kapattı / vazgeçti.
class PlayBillingCancelledException extends PlayBillingException {
  PlayBillingCancelledException([String? message])
      : super(
          message ?? 'Satın alma iptal edildi.',
          code: 'user_cancelled',
        );
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

  static const _purchaseTimeout = Duration(minutes: 3);

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _purchaseSub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        debugPrint('PURCHASE_FAILED stream_error: $e');
        _failAllPendingPurchases(
          e,
          reason: 'stream_error',
        );
        _completeRestore();
      },
    );
    _initialized = true;
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _initialized = false;
    _failAllPendingPurchases(
      PlayBillingException('Billing servisi kapatıldı.'),
      reason: 'dispose',
    );
  }

  Future<List<ProductDetails>> queryProducts(Set<String> productIds) async {
    if (kIsWeb) {
      debugPrint('PLAY BILLING: web — queryProducts skipped (use queryProductPrices)');
      return const [];
    }
    await init();
    final available = await _iap.isAvailable();
    if (!available) {
      throw PlayBillingException(
        'Google Play odeme servisi kullanilamiyor. Cihazin Play Store ile giris yaptigindan emin olun.',
      );
    }

    debugPrint('PLAY BILLING queryProductDetails: ${productIds.join(', ')}');
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('PLAY BILLING query error: ${response.error!.message}');
      throw PlayBillingException(tokenBillingProductsNotReadyMessage);
    }

    debugPrint('PLAY BILLING query OK: ${response.productDetails.length} product(s)');
    for (final product in response.productDetails) {
      debugPrint('PLAY BILLING product: ${product.id} price=${product.price}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('PLAY BILLING not found: ${response.notFoundIDs.join(', ')}');
    }

    return response.productDetails;
  }

  Future<Map<String, String>> queryProductPrices(Set<String> productIds) async {
    if (kIsWeb) {
      debugPrint('PLAY BILLING: web — returning mock shop prices');
      final prices = <String, String>{};
      for (final id in productIds) {
        final mock = mockPriceForProductId(id);
        if (mock != null) {
          prices[id] = mock;
          debugPrint('PLAY BILLING mock: $id price=$mock');
        }
      }
      return prices;
    }

    final products = await queryProducts(productIds);
    final prices = <String, String>{};
    for (final product in products) {
      if (product.price.isNotEmpty) {
        prices[product.id] = product.price;
      }
    }
    return prices;
  }

  bool get isWebMockShop => kIsWeb;

  Future<PlayPurchaseResult> buyConsumable(String productId) async {
    if (kIsWeb) {
      throw PlayBillingException(
        'Satın alma yalnızca Android uygulamasında kullanılabilir.',
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
    debugPrint('PURCHASE_STARTED productId=$productId');

    try {
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: products.first),
      );

      if (!started) {
        _purchaseCompleters.remove(productId);
        debugPrint('PURCHASE_FAILED productId=$productId reason=not_started');
        throw PlayBillingException('Odeme baslatilamadi.');
      }

      return await completer.future.timeout(
        _purchaseTimeout,
        onTimeout: () {
          _purchaseCompleters.remove(productId);
          debugPrint('PURCHASE_TIMEOUT productId=$productId');
          throw PlayBillingException(
            'Satin alma islemi zaman asimina ugradi. Google Play penceresini kapattiysaniz tekrar deneyin.',
            code: 'timeout',
          );
        },
      );
    } on PlatformException catch (e) {
      _purchaseCompleters.remove(productId);
      if (_isPlatformCancellation(e)) {
        debugPrint('PURCHASE_CANCELLED productId=$productId platform=${e.code}');
        throw PlayBillingCancelledException();
      }
      debugPrint('PURCHASE_FAILED productId=$productId platform=${e.code} ${e.message}');
      throw PlayBillingException(
        e.message?.isNotEmpty == true ? e.message! : 'Odeme basarisiz oldu.',
        code: e.code,
      );
    } catch (e) {
      if (e is PlayBillingException || e is PlayBillingCancelledException) {
        rethrow;
      }
      _purchaseCompleters.remove(productId);
      debugPrint('PURCHASE_FAILED productId=$productId error=$e');
      rethrow;
    }
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
      await _handlePurchaseUpdate(purchase);
    }

    if (_restoreCompleter != null && _restoredPurchases.isNotEmpty) {
      _completeRestore();
    }
  }

  Future<void> _handlePurchaseUpdate(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final isKnownProduct =
        productId.isNotEmpty && allBillingProductIds.contains(productId);
    final isAnonymous =
        productId.isEmpty && _purchaseCompleters.isNotEmpty;

    if (!isKnownProduct && !isAnonymous) {
      return;
    }

    if (purchase.status == PurchaseStatus.pending) {
      return;
    }

    if (purchase.status == PurchaseStatus.canceled ||
        _isPurchaseCancelled(purchase)) {
      debugPrint(
        'PURCHASE_CANCELLED productId=${productId.isEmpty ? 'anonymous' : productId}',
      );
      _resolvePendingCancellation(
        productId: productId,
        purchase: purchase,
      );
      await _completePlayPurchaseIfNeeded(purchase);
      return;
    }

    if (purchase.status == PurchaseStatus.error) {
      debugPrint(
        'PURCHASE_FAILED productId=${productId.isEmpty ? 'anonymous' : productId} '
        'error=${purchase.error?.message}',
      );
      _resolvePendingFailure(
        productId: productId,
        message: purchase.error?.message.isNotEmpty == true
            ? purchase.error!.message
            : 'Odeme basarisiz oldu.',
      );
      await _completePlayPurchaseIfNeeded(purchase);
      return;
    }

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      final resolvedProductId = isKnownProduct
          ? productId
          : (_purchaseCompleters.length == 1
              ? _purchaseCompleters.keys.first
              : productId);

      final token = purchase.verificationData.serverVerificationData.trim();
      if (token.isEmpty) {
        _resolvePendingFailure(
          productId: resolvedProductId,
          message: 'Play satin alma dogrulamasi alinmadi.',
        );
        await _completePlayPurchaseIfNeeded(purchase);
        return;
      }

      final result = PlayPurchaseResult(
        productId: resolvedProductId,
        purchaseToken: token,
        purchaseId: purchase.purchaseID,
        transactionDate: purchase.transactionDate,
        source: purchase.status == PurchaseStatus.restored
            ? PurchaseSource.restored
            : PurchaseSource.purchased,
      );

      final completer = _purchaseCompleters.remove(resolvedProductId);
      if (completer != null && !completer.isCompleted) {
        debugPrint('PURCHASE_SUCCESS productId=$resolvedProductId');
        completer.complete(result);
      }

      if (purchase.status == PurchaseStatus.restored) {
        _restoredPurchases.add(result);
      }

      await _completePlayPurchaseIfNeeded(purchase);
    }
  }

  void _resolvePendingCancellation({
    required String productId,
    required PurchaseDetails purchase,
  }) {
    if (productId.isNotEmpty) {
      _completePurchaseCancelled(productId);
      return;
    }
    for (final id in _purchaseCompleters.keys.toList()) {
      _completePurchaseCancelled(id);
    }
  }

  void _resolvePendingFailure({
    required String productId,
    required String message,
  }) {
    if (productId.isNotEmpty) {
      _completePurchaseError(productId, message);
      return;
    }
    for (final id in _purchaseCompleters.keys.toList()) {
      _completePurchaseError(id, message);
    }
  }

  void _completePurchaseCancelled(String productId) {
    final completer = _purchaseCompleters.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(PlayBillingCancelledException());
    }
  }

  void _completePurchaseError(String productId, String message) {
    final completer = _purchaseCompleters.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(PlayBillingException(message));
    }
  }

  void _failAllPendingPurchases(
    Object error, {
    required String reason,
  }) {
    final ids = _purchaseCompleters.keys.toList();
    for (final productId in ids) {
      final completer = _purchaseCompleters.remove(productId);
      if (completer == null || completer.isCompleted) continue;
      if (error is PlayBillingCancelledException) {
        debugPrint('PURCHASE_CANCELLED productId=$productId reason=$reason');
        completer.completeError(error);
      } else if (error is PlayBillingException) {
        debugPrint('PURCHASE_FAILED productId=$productId reason=$reason');
        completer.completeError(error);
      } else {
        debugPrint('PURCHASE_FAILED productId=$productId reason=$reason error=$error');
        completer.completeError(PlayBillingException('Odeme akisi hatasi: $error'));
      }
    }
  }

  bool _isPurchaseCancelled(PurchaseDetails purchase) {
    if (purchase.status == PurchaseStatus.canceled) return true;
    final error = purchase.error;
    if (error == null) return false;
    final code = error.code.toLowerCase();
    final message = error.message.toLowerCase();
    final details = '${error.details ?? ''}'.toLowerCase();
    return code.contains('cancel') ||
        message.contains('cancel') ||
        message.contains('usercanceled') ||
        details.contains('usercanceled') ||
        details.contains('user_cancel');
  }

  bool _isPlatformCancellation(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = '${e.message}'.toLowerCase();
    return code.contains('cancel') ||
        code == 'user_canceled' ||
        code == 'purchase_cancelled' ||
        message.contains('cancel') ||
        message.contains('usercanceled');
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
