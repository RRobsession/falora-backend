import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/ai_config.dart';
import 'package:flutter/foundation.dart';

/// Fal gönderim teşhisi — release build'de de logcat'e düşer (debugPrint).
class FortuneSubmitLogger {
  FortuneSubmitLogger._();

  static Future<bool> authTokenExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final token = await user.getIdToken(true);
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logSubmitStart({
    required String fortuneType,
    required String selectedReader,
    required bool isManualReader,
    String? endpoint,
    Map<String, dynamic>? requestBody,
  }) async {
    final hasToken = await authTokenExists();
    debugPrint('FORTUNE SUBMIT START');
    debugPrint('FORTUNE TYPE: $fortuneType');
    debugPrint('SELECTED READER: $selectedReader');
    debugPrint('IS MANUAL READER: $isManualReader');
    debugPrint('API_BASE_URL: $apiBaseUrl');
    if (endpoint != null) {
      debugPrint('API ENDPOINT: $endpoint');
    }
    debugPrint('AUTH TOKEN EXISTS: $hasToken');
    if (requestBody != null) {
      debugPrint('REQUEST BODY: $requestBody');
    }
  }

  static void logResponse({
    required int status,
    required String body,
  }) {
    final preview = body.length > 800 ? '${body.substring(0, 800)}...' : body;
    debugPrint('RESPONSE STATUS: $status');
    debugPrint('RESPONSE BODY: $preview');
  }

  static void logError(Object error, [StackTrace? stackTrace]) {
    debugPrint('FORTUNE SUBMIT ERROR: $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}

/// Jeton paketi Play ürünleri henüz aktif değilse gösterilecek mesaj.
const tokenBillingProductsNotReadyMessage =
    'Jeton paketleri henüz hazır değil. Lütfen daha sonra tekrar deneyin.';

@Deprecated('Use tokenBillingProductsNotReadyMessage')
const manualBillingProductsNotReadyMessage = tokenBillingProductsNotReadyMessage;
