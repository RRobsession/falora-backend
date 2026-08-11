import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_links_config.dart';
import '../firebase_options.dart';

/// Firebase e-posta doğrulama: doğrulama sonrası Hosting sonuç sayfasına döner.
///
/// [emailVerificationContinueUrl] → `https://tombikteyze.web.app/email-verified.html`
/// (Authorized domain / Hosting sonuç sayfası.)
///
/// [handleCodeInApp]: false — AndroidManifest'te App Links / Dynamic Links yok;
/// doğrulama web sonuç sayfasında tamamlanır, kullanıcı uygulamaya döner.
Future<void> sendAppEmailVerification(User user) {
  return user.sendEmailVerification(
    ActionCodeSettings(
      url: emailVerificationContinueUrl,
      handleCodeInApp: false,
      androidPackageName: androidPackageName,
      androidInstallApp: true,
      androidMinimumVersion: '1',
      iOSBundleId: DefaultFirebaseOptions.ios.iosBundleId,
    ),
  );
}

/// Kullanıcıyı yeniler; e-posta doğrulanmışsa true.
Future<bool> reloadAndCheckEmailVerified(User user) async {
  await user.reload();
  final refreshed = FirebaseAuth.instance.currentUser;
  final verified = refreshed?.emailVerified ?? false;
  if (kDebugMode) {
    debugPrint(
      'Email verification check: uid=${refreshed?.uid} verified=$verified',
    );
  }
  return verified;
}
