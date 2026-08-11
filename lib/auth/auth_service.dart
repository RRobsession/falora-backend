import 'package:falora/auth/firebase_auth_service.dart';
import 'package:falora/models/app_user.dart';

class RegisterResult {
  const RegisterResult({
    required this.user,
    required this.verificationEmailSent,
  });

  final AppUser user;
  final bool verificationEmailSent;
}

abstract class AuthService {
  Future<AppUser?> getCurrentUser();

  /// Kayıt sonrası oturum açık kalır; e-posta doğrulaması gerekir.
  Future<RegisterResult> register({
    required String email,
    required String password,
    String? referralCode,
  });

  Future<AppUser> login({
    required String email,
    required String password,
  });

  /// Google hesabı ile giriş. Kullanıcı iptal ederse [AuthException.userCancelled].
  Future<AppUser> signInWithGoogle();

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> logout();

  /// Tüm kullanıcı verilerini ve Firebase Auth hesabını kalıcı olarak siler.
  /// [password] güvenlik doğrulaması gerektiğinde yeniden kimlik doğrulama için kullanılır.
  Future<void> deleteAccount({String? password});

  Future<void> sendVerificationEmail();

  /// Firebase kullanıcısını yeniler; doğrulandıysa Firestore günceller.
  Future<bool> reloadEmailVerificationStatus();

  /// Oturum değişimlerini dinle (reload sonrası AuthGate yenilensin).
  Stream<void> watchAuthState();
}

AuthService createAuthService() => FirebaseAuthService.instance;

class AuthException implements Exception {
  AuthException(
    this.message, {
    this.requiresReauth = false,
    this.userCancelled = false,
  });

  final String message;
  final bool requiresReauth;
  final bool userCancelled;

  @override
  String toString() => message;
}
