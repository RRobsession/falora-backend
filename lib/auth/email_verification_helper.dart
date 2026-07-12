import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/auth/auth_service.dart';
import 'package:falora/auth/firebase_auth_service.dart';
import 'package:falora/firebase_options.dart';
import 'package:flutter/foundation.dart';

/// Firebase e-posta doğrulama bağlantısı için yetkili domain.
const emailVerificationContinueUrl = 'https://falora35.firebaseapp.com';

ActionCodeSettings buildEmailVerificationActionCodeSettings() {
  if (kIsWeb) {
    return ActionCodeSettings(
      url: emailVerificationContinueUrl,
      handleCodeInApp: true,
    );
  }

  return ActionCodeSettings(
    url: emailVerificationContinueUrl,
    handleCodeInApp: true,
    androidPackageName: 'com.rrlime.falora',
    androidInstallApp: true,
    androidMinimumVersion: '1',
    iOSBundleId: DefaultFirebaseOptions.ios.iosBundleId,
  );
}

/// Firebase Authentication üzerinden doğrulama e-postası gönderir.
Future<void> sendVerificationEmail() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw AuthException('Oturum bulunamadı, doğrulama e-postası gönderilemedi.');
  }
  if (user.emailVerified) return;

  debugPrint('EMAIL_VERIFICATION_SEND_START uid=${user.uid} via=firebase_auth');

  try {
    await user.sendEmailVerification(
      buildEmailVerificationActionCodeSettings(),
    );
    debugPrint('EMAIL_VERIFICATION_SEND_SUCCESS');
  } on FirebaseAuthException catch (e) {
    debugPrint(
      'EMAIL_VERIFICATION_FAILED code=${e.code} message=${e.message}',
    );
    throw AuthException(FirebaseAuthService.mapVerificationEmailError(e));
  } catch (e, stackTrace) {
    debugPrint('EMAIL_VERIFICATION_FAILED: $e');
    debugPrint(stackTrace.toString());
    throw AuthException(
      'Doğrulama e-postası gönderilemedi. Lütfen tekrar deneyin.',
    );
  }
}
