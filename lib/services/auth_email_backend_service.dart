import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthEmailBackendException implements Exception {
  AuthEmailBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Railway backend üzerinden Resend auth e-postaları.
class AuthEmailBackendService {
  AuthEmailBackendService._();

  static final AuthEmailBackendService instance = AuthEmailBackendService._();

  static const _timeout = Duration(seconds: 30);

  Future<void> sendVerificationEmail() async {
    final uri = Uri.parse('$apiBaseUrl/auth/send-verification-email');
    BackendAuthClient.logRequest('/auth/send-verification-email');

    late final http.Response response;
    try {
      final headers = await BackendAuthClient.authHeaders();
      response = await http.post(uri, headers: headers).timeout(_timeout);
    } on BackendAuthException catch (e) {
      throw AuthEmailBackendException(e.message);
    } catch (e) {
      throw AuthEmailBackendException('Bağlantı hatası: $e');
    }

    BackendAuthClient.logRequest(
      '/auth/send-verification-email',
      statusCode: response.statusCode,
    );

    _throwIfFailed(
      response,
      fallback: 'Doğrulama e-postası gönderilemedi.',
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final uri = Uri.parse('$apiBaseUrl/auth/send-password-reset-email');
    BackendAuthClient.logRequest('/auth/send-password-reset-email');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(_timeout);
    } catch (e) {
      throw AuthEmailBackendException('Bağlantı hatası: $e');
    }

    BackendAuthClient.logRequest(
      '/auth/send-password-reset-email',
      statusCode: response.statusCode,
    );

    _throwIfFailed(
      response,
      fallback: 'Şifre sıfırlama e-postası gönderilemedi.',
    );
  }

  void _throwIfFailed(
    http.Response response, {
    required String fallback,
  }) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthEmailBackendException(
        'Oturum doğrulanamadı. Lütfen tekrar giriş yapın.',
      );
    }

    if (response.statusCode == 429) {
      throw AuthEmailBackendException(
        'Çok fazla istek. Lütfen biraz sonra tekrar deneyin.',
      );
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['ok'] == true) return;
      } catch (_) {}
      throw AuthEmailBackendException('E-posta yanıtı işlenemedi.');
    }

    var detail = fallback;
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['error'] is String && (data['error'] as String).isNotEmpty) {
        detail = data['error'] as String;
      }
    } catch (_) {}

    if (kDebugMode) {
      debugPrint('AUTH EMAIL BACKEND body: ${response.body}');
    }
    throw AuthEmailBackendException('$detail (HTTP ${response.statusCode}).');
  }
}
