import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthVerificationBackendException implements Exception {
  AuthVerificationBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthVerificationBackendService {
  AuthVerificationBackendService._();

  static final AuthVerificationBackendService instance =
      AuthVerificationBackendService._();

  static const _timeout = Duration(seconds: 20);

  Future<void> sendVerificationEmail() async {
    final uri = Uri.parse('$apiBaseUrl/auth/send-verification-email');
    BackendAuthClient.logRequest('/auth/send-verification-email');

    late final http.Response response;
    try {
      final headers = await BackendAuthClient.authHeaders();
      response = await http
          .post(uri, headers: headers)
          .timeout(_timeout);
    } on BackendAuthException catch (e) {
      throw AuthVerificationBackendException(e.message);
    } catch (e) {
      throw AuthVerificationBackendException('Bağlantı hatası: $e');
    }

    BackendAuthClient.logRequest(
      '/auth/send-verification-email',
      statusCode: response.statusCode,
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthVerificationBackendException(
        'Oturum doğrulanamadı. Lütfen tekrar giriş yapın.',
      );
    }

    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('AUTH VERIFY BACKEND body: ${response.body}');
      }
      throw AuthVerificationBackendException(
        'Doğrulama e-postası gönderilemedi (HTTP ${response.statusCode}).',
      );
    }

    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['ok'] == true) return;
    } catch (_) {}

    throw AuthVerificationBackendException(
      'Doğrulama e-postası yanıtı işlenemedi.',
    );
  }
}
