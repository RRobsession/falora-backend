import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FortuneBackendException implements Exception {
  FortuneBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FortuneRefundResult {
  const FortuneRefundResult({
    required this.ok,
    required this.reason,
    required this.amount,
  });

  final bool ok;
  final String reason;
  final int amount;

  bool get wasRefunded => ok && amount > 0;
  bool get alreadyRefunded => ok && reason == 'already_refunded';
}

class FortuneBackendService {
  FortuneBackendService._();

  static final FortuneBackendService instance = FortuneBackendService._();

  static const _timeout = Duration(seconds: 15);

  Future<FortuneRefundResult> refundFailedRequest({
    required String requestId,
    required bool isCouple,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/fortune/refund');
      final response = await http
          .post(
            uri,
            headers: await BackendAuthClient.authHeaders(),
            body: jsonEncode({
              'requestId': requestId,
              'type': isCouple ? 'couple' : 'fortune',
            }),
          )
          .timeout(_timeout);

      BackendAuthClient.logRequest(
        '/fortune/refund',
        statusCode: response.statusCode,
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw FortuneBackendException('Oturum doğrulanamadı.');
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        throw FortuneBackendException('Geçersiz yanıt');
      }

      final map = Map<String, dynamic>.from(data);
      return FortuneRefundResult(
        ok: map['ok'] == true,
        reason: map['reason']?.toString() ?? 'unknown',
        amount: (map['amount'] as num?)?.toInt() ?? 0,
      );
    } on FortuneBackendException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FORTUNE REFUND error: $e');
      }
      throw FortuneBackendException('Jeton iadesi tamamlanamadı.');
    }
  }
}
