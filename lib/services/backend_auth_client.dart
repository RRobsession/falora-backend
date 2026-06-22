import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Backend API çağrıları için Firebase ID token başlıkları.
class BackendAuthClient {
  BackendAuthClient._();

  static Future<Map<String, String>> authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw BackendAuthException('Oturum bulunamadı.');
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw BackendAuthException('Kimlik doğrulama tokenı alınamadı.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static void logRequest(String path, {int? statusCode, int? resultLength}) {
    if (!kDebugMode) return;
    if (statusCode != null) {
      debugPrint('API $path → $statusCode');
      if (resultLength != null) {
        debugPrint('API $path result length=$resultLength');
      }
      return;
    }
    debugPrint('API $path start');
  }
}

class BackendAuthException implements Exception {
  BackendAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
