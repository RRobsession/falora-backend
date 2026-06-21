import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/services/fortune_submit_logger.dart';
import 'package:falora/services/play_billing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BillingBackendException implements Exception {
  BillingBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ManualPurchaseVerificationResult {
  const ManualPurchaseVerificationResult({
    required this.requestId,
    required this.alreadyProcessed,
  });

  final String requestId;
  final bool alreadyProcessed;
}

class TokenPurchaseVerificationResult {
  const TokenPurchaseVerificationResult({
    required this.tokensGranted,
    required this.alreadyProcessed,
  });

  final int tokensGranted;
  final bool alreadyProcessed;
}

class BillingRestoreSummary {
  const BillingRestoreSummary({
    required this.processedCount,
    required this.lastProductId,
  });

  final int processedCount;
  final String? lastProductId;
}

class BillingBackendService {
  BillingBackendService._();

  static final BillingBackendService instance = BillingBackendService._();

  Future<ManualPurchaseVerificationResult> completeManualPurchase({
    required PlayPurchaseResult purchase,
    required String userId,
    required String userEmail,
    required String requestId,
    required String category,
    required String readerId,
    required String readerName,
    required int priceTRY,
    required int questionLimit,
    required bool requiresIntention,
    required String name,
    required int age,
    required String zodiac,
    required String intention,
    required List<String> questions,
    required List<Map<String, String>> imageInfo,
  }) async {
    final data = await _post(
      '/billing/manual-fortune/complete',
      {
        'userId': userId,
        'userEmail': userEmail,
        'requestId': requestId,
        'productId': purchase.productId,
        'purchaseToken': purchase.purchaseToken,
        'purchaseId': purchase.purchaseId,
        'source': purchase.source.name,
        'transactionDate': purchase.transactionDate,
        'category': category,
        'readerId': readerId,
        'readerName': readerName,
        'priceTRY': priceTRY,
        'questionLimit': questionLimit,
        'requiresIntention': requiresIntention,
        'name': name,
        'age': age,
        'zodiac': zodiac,
        'intention': intention,
        'questions': questions,
        'imageInfo': imageInfo,
      },
    );

    return ManualPurchaseVerificationResult(
      requestId: data['requestId'] as String? ?? requestId,
      alreadyProcessed: data['alreadyProcessed'] == true,
    );
  }

  Future<TokenPurchaseVerificationResult> completeTokenPurchase({
    required PlayPurchaseResult purchase,
    required String userId,
  }) async {
    final data = await _post(
      '/billing/tokens/complete',
      {
        'userId': userId,
        'productId': purchase.productId,
        'purchaseToken': purchase.purchaseToken,
        'purchaseId': purchase.purchaseId,
        'source': purchase.source.name,
        'transactionDate': purchase.transactionDate,
      },
    );

    return TokenPurchaseVerificationResult(
      tokensGranted: (data['tokensGranted'] as num?)?.toInt() ?? 0,
      alreadyProcessed: data['alreadyProcessed'] == true,
    );
  }

  Future<BillingRestoreSummary> restoreHistory() async {
    final data = await _post('/billing/restore', const {});
    return BillingRestoreSummary(
      processedCount: (data['processedCount'] as num?)?.toInt() ?? 0,
      lastProductId: data['lastProductId'] as String?,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = await BackendAuthClient.authHeaders();
    await FortuneSubmitLogger.logSubmitStart(
      fortuneType: payload['category']?.toString() ?? 'billing',
      selectedReader: payload['readerId']?.toString() ??
          payload['productId']?.toString() ??
          'unknown',
      isManualReader: path.contains('manual-fortune'),
      endpoint: uri.toString(),
      requestBody: _sanitizePayload(payload),
    );

    final response = await http
        .post(uri, headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 30));

    FortuneSubmitLogger.logResponse(
      status: response.statusCode,
      body: response.body,
    );

    Map<String, dynamic> data = const {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _mapBillingError(response.statusCode, data['error']);
      FortuneSubmitLogger.logError(message);
      throw BillingBackendException(message);
    }

    if (kDebugMode) {
      debugPrint('BILLING API $path OK');
    }

    return data;
  }

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
    final sanitized = Map<String, dynamic>.from(payload);
    if (sanitized.containsKey('purchaseToken')) {
      final token = sanitized['purchaseToken']?.toString() ?? '';
      sanitized['purchaseToken'] =
          token.isEmpty ? '' : '${token.substring(0, 8)}...';
    }
    if (sanitized.containsKey('imageInfo')) {
      final images = sanitized['imageInfo'];
      if (images is List) {
        sanitized['imageInfo'] = '${images.length} image(s)';
      }
    }
    return sanitized;
  }

  String _mapBillingError(int statusCode, dynamic rawError) {
    final error = rawError?.toString() ?? '';
    if (statusCode == 404) {
      return manualBillingProductsNotReadyMessage;
    }
    if (statusCode == 503 &&
        error.toLowerCase().contains('google play servis')) {
      return manualBillingProductsNotReadyMessage;
    }
    if (error.toLowerCase().contains('google play doğrulaması')) {
      return manualBillingProductsNotReadyMessage;
    }
    if (error.isNotEmpty) return error;
    return 'Satın alma doğrulaması tamamlanamadı. Lütfen tekrar deneyin.';
  }
}
