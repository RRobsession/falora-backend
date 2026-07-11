import 'package:falora/auth/auth_service.dart';
import 'package:falora/services/auth_email_backend_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Doğrulama e-postası yalnızca Railway → Resend üzerinden gönderilir.
/// Firebase varsayılan `sendEmailVerification` kullanılmaz.
Future<void> sendVerificationEmail() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw AuthException('Oturum bulunamadı, doğrulama e-postası gönderilemedi.');
  }
  if (user.emailVerified) return;

  debugPrint('EMAIL_VERIFICATION_SEND_START uid=${user.uid} via=railway');
  try {
    await AuthEmailBackendService.instance.sendVerificationEmail();
    debugPrint('EMAIL_VERIFICATION_SEND_SUCCESS');
  } on AuthEmailBackendException catch (e) {
    throw AuthException(e.message);
  } catch (e, stackTrace) {
    debugPrint('EMAIL_VERIFICATION_BACKEND_FAILED: $e');
    debugPrint(stackTrace.toString());
    throw AuthException(
      'Doğrulama e-postası gönderilemedi. Lütfen tekrar deneyin.',
    );
  }
}
