import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/auth/email_verification_helper.dart' as email_verification;
import 'package:falora/auth/auth_service.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/services/fortune_storage_service.dart';
import 'package:falora/services/manual_fortune_storage_service.dart';
import 'package:falora/services/referral_service.dart';
import 'package:falora/services/notification_service.dart';
import 'package:falora/services/auth_email_backend_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/token_config.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService._();

  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  @override
  Stream<void> watchAuthState() =>
      _auth.authStateChanges().map((_) {});

  /// Firebase Auth kullanıcısını sunucudan yeniler; güncel currentUser döner.
  Future<User?> _reloadCurrentUser({String? logPrefix}) async {
    final before = FirebaseAuth.instance.currentUser;
    if (before == null) return null;

    if (logPrefix != null) {
      debugPrint('$logPrefix BEFORE RELOAD emailVerified: ${before.emailVerified}');
    }

    await FirebaseAuth.instance.currentUser?.reload();

    final after = FirebaseAuth.instance.currentUser;
    if (logPrefix != null && after != null) {
      debugPrint('$logPrefix AFTER RELOAD emailVerified: ${after.emailVerified}');
    }

    return after;
  }

  Future<void> _sendVerificationEmailToCurrentUser() async {
    await email_verification.sendVerificationEmail();
  }

  Future<void> _deleteNewUserFirestoreDoc(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
      debugPrint('REGISTER_USER_DOC_ROLLBACK_OK uid=$uid');
    } catch (e) {
      debugPrint('REGISTER_USER_DOC_ROLLBACK_FAILED uid=$uid error=$e');
    }
  }

  Future<void> _rollbackNewAuthAccount(User? user) async {
    if (user == null) return;
    debugPrint('REGISTER_AUTH_ROLLBACK_DELETE_START');
    await _deleteNewUserFirestoreDoc(user.uid);
    try {
      await user.delete();
      debugPrint('REGISTER_AUTH_ROLLBACK_DELETE_SUCCESS');
    } catch (e, stackTrace) {
      debugPrint('REGISTER_AUTH_ROLLBACK_DELETE_FAILED: $e');
      debugPrint(stackTrace.toString());
    }
  }

  static String mapVerificationEmailError(FirebaseAuthException e) {
    if (e.code == 'too-many-requests') {
      return 'Çok fazla deneme yaptınız, birkaç dakika sonra tekrar deneyin.';
    }
    final mapped = mapFirebaseAuthError(e);
    return '$mapped (${e.code}: ${e.message ?? ''})';
  }

  Future<void> _syncEmailVerifiedToFirestore(String uid) async {
    try {
      await _db.collection('users').doc(uid).set(
        {
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('Firestore emailVerified synced to true for $uid');
    } catch (e, stackTrace) {
      debugPrint('Firestore emailVerified update failed: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Tek kaynak: FirebaseAuth.instance.currentUser.emailVerified
  bool _firebaseEmailVerified(User? user) => user?.emailVerified ?? false;

  AppUser _appUserFromFirebaseAndFirestore(User fbUser, AppUser profile) {
    final verified = _firebaseEmailVerified(fbUser);
    return profile.copyWith(emailVerified: verified);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final fbUser = await _reloadCurrentUser();
    if (fbUser == null) return null;

    final emailVerified = _firebaseEmailVerified(fbUser);
    debugPrint('GET CURRENT USER emailVerified (Firebase Auth): $emailVerified');

    if (emailVerified) {
      await _syncEmailVerifiedToFirestore(fbUser.uid);
    }

    try {
      final profile = await _loadUserProfile(fbUser);
      return _appUserFromFirebaseAndFirestore(fbUser, profile);
    } catch (e, stackTrace) {
      debugPrint('Firestore user fetch failed: $e');
      debugPrint(stackTrace.toString());
      try {
        final recovered = await TokenService.instance.ensureUserDocument(
          uid: fbUser.uid,
          name: fbUser.displayName?.trim() ?? '',
          email: fbUser.email?.trim().toLowerCase() ?? '',
        );
        debugPrint('ENSURE_USER_DOC_RECOVERY_SUCCESS uid=${fbUser.uid}');
        return _appUserFromFirebaseAndFirestore(fbUser, recovered);
      } catch (ensureError, ensureStack) {
        debugPrint('ensureUserDocument failed: $ensureError');
        debugPrint(ensureStack.toString());
        return AppUser(
          userId: fbUser.uid,
          name: fbUser.displayName?.trim() ?? '',
          email: fbUser.email?.trim().toLowerCase() ?? '',
          tokens: initialUserTokens,
          emailVerified: emailVerified,
        );
      }
    }
  }

  @override
  Future<RegisterResult> register({
    required String email,
    required String password,
    String? referralCode,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    debugPrint('REGISTER_BASIC_START');
    if (kDebugMode) {
      debugPrint('REGISTER email hash: ${normalizedEmail.hashCode}');
    }

    try {
      if (referralCode != null && referralCode.trim().isNotEmpty) {
        debugPrint('REFERRAL_CODE_ENTERED code=${referralCode.trim()}');
      }

      final cred = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final uid = cred.user!.uid;
      final newUser = cred.user;

      debugPrint('REGISTER_AUTH_CREATED uid: $uid');
      debugPrint('REGISTER_AUTH_TOKEN_EMAIL: ${newUser?.email ?? '<null>'}');

      var verificationEmailSent = false;
      try {
        debugPrint('REGISTER_USER_DOC_CREATE_START uid: $uid');
        await TokenService.instance.ensureUserDocument(
          uid: uid,
          email: normalizedEmail,
        );
        debugPrint('REGISTER_USER_DOC_CREATE_SUCCESS uid: $uid');
        debugPrint('REGISTER_BASIC_SUCCESS');

        if (referralCode != null && referralCode.trim().isNotEmpty) {
          ReferralService.instance.storePendingReferralCode(uid, referralCode);
        }

        try {
          await _sendVerificationEmailToCurrentUser();
          verificationEmailSent = true;
          debugPrint('EMAIL_VERIFICATION_REQUIRED');
        } on AuthException catch (e) {
          debugPrint('EMAIL_VERIFICATION_DEFERRED: ${e.message}');
        }
      } on AuthException {
        await _rollbackNewAuthAccount(newUser);
        rethrow;
      } on FirebaseException catch (e, stackTrace) {
        debugPrint('REGISTER_USER_DOC_CREATE_FAILED uid: $uid code=${e.code}');
        debugPrint(stackTrace.toString());
        await _rollbackNewAuthAccount(newUser);
        final message = e.code == 'permission-denied'
            ? 'Hesap kaydı tamamlanamadı (veritabanı izni). Lütfen tekrar deneyin.'
            : 'Hesap kaydı tamamlanamadı. Lütfen tekrar deneyin.';
        throw AuthException(message);
      } catch (e, stackTrace) {
        debugPrint('REGISTER_USER_DOC_CREATE_FAILED uid: $uid error: $e');
        debugPrint(stackTrace.toString());
        await _rollbackNewAuthAccount(newUser);
        throw AuthException('Hesap kaydı tamamlanamadı. Lütfen tekrar deneyin.');
      }

      return RegisterResult(
        user: AppUser(
          userId: uid,
          name: '',
          displayName: '',
          email: normalizedEmail,
          tokens: initialUserTokens,
          emailVerified: false,
        ),
        verificationEmailSent: verificationEmailSent,
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase register error code: ${e.code}');
      debugPrint('Firebase register error message: ${e.message}');
      if (e.code == 'email-already-in-use') {
        debugPrint('EMAIL_ALREADY_EXISTS_BROKEN_RECOVERY hint=try_login');
      }
      throw AuthException(mapFirebaseAuthError(e));
    } catch (e, stackTrace) {
      debugPrint('Unknown register error: $e');
      debugPrint(stackTrace.toString());
      throw AuthException('Kayıt hatası: $e');
    }
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    debugPrint('LOGIN START');
    if (kDebugMode) {
      debugPrint('LOGIN email hash: ${trimmedEmail.hashCode}');
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password.trim(),
      );

      final fbUser = await _reloadCurrentUser(logPrefix: 'LOGIN');
      if (fbUser == null) {
        throw AuthException('Oturum açılamadı.');
      }

      debugPrint(
        'LOGIN SUCCESS uid: ${fbUser.uid} | emailVerified (Firebase Auth): ${fbUser.emailVerified}',
      );

      if (fbUser.emailVerified) {
        await _syncEmailVerifiedToFirestore(fbUser.uid);
      }

      try {
        final profile = await _loadUserProfile(fbUser);
        return _appUserFromFirebaseAndFirestore(fbUser, profile);
      } catch (e, stackTrace) {
        debugPrint('Firestore user fetch failed on login: $e');
        debugPrint(stackTrace.toString());
        try {
          final profile = await TokenService.instance.ensureUserDocument(
            uid: fbUser.uid,
            name: fbUser.displayName?.trim() ?? '',
            email: fbUser.email?.trim().toLowerCase() ?? '',
          );
          debugPrint('ENSURE_USER_DOC_RECOVERY_SUCCESS uid=${fbUser.uid}');
          return _appUserFromFirebaseAndFirestore(fbUser, profile);
        } catch (ensureError) {
          debugPrint('ensureUserDocument failed on login: $ensureError');
          return AppUser(
            userId: fbUser.uid,
            name: fbUser.displayName?.trim() ?? '',
            email: fbUser.email?.trim().toLowerCase() ?? '',
            tokens: initialUserTokens,
            emailVerified: _firebaseEmailVerified(fbUser),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase login error code: ${e.code}');
      debugPrint('Firebase login error message: ${e.message}');
      throw AuthException(mapFirebaseAuthError(e, login: true));
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Unknown login error: $e');
      debugPrint(stackTrace.toString());
      throw AuthException('Giriş hatası: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = _normalizeEmail(email);
    try {
      await AuthEmailBackendService.instance.sendPasswordResetEmail(
        email: normalizedEmail,
      );
    } on AuthEmailBackendException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Şifre sıfırlama bağlantısı gönderilemedi: $e');
    }
  }

  @override
  Future<void> sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AuthException('Oturum bulunamadı.');
    }
    if (user.emailVerified) return;

    await _sendVerificationEmailToCurrentUser();
  }

  @override
  Future<bool> reloadEmailVerificationStatus() async {
    debugPrint('EMAIL_VERIFICATION_RELOAD');

    final before = FirebaseAuth.instance.currentUser;
    if (before == null) {
      debugPrint('VERIFY FAILED (no user)');
      throw AuthException('Oturum bulunamadı.');
    }

    debugPrint('BEFORE RELOAD emailVerified: ${before.emailVerified}');

    await FirebaseAuth.instance.currentUser?.reload();
    await FirebaseAuth.instance.currentUser?.getIdToken(true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('VERIFY FAILED (no user after reload)');
      return false;
    }

    debugPrint('AFTER RELOAD emailVerified: ${user.emailVerified}');

    if (!user.emailVerified) {
      debugPrint('VERIFY FAILED');
      return false;
    }

    await _syncEmailVerifiedToFirestore(user.uid);

    debugPrint('EMAIL_VERIFICATION_CONFIRMED');
    return true;
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    debugPrint('FIREBASE LOGOUT ok');
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('Oturum bulunamadı.');
    }

    if (password != null) {
      final email = user.email?.trim();
      if (email == null || email.isEmpty) {
        throw AuthException('E-posta adresi bulunamadı.');
      }
      try {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: email,
            password: password,
          ),
        );
      } on FirebaseAuthException catch (e) {
        throw AuthException(_mapReauthError(e));
      }
    }

    final uid = user.uid;

    try {
      await NotificationService.instance.clearForAccountDeletion(uid);
      await FortuneStorageService.instance.deleteAllUserData(uid);
      await ManualFortuneStorageService.instance.deleteUserRequests(uid);
      await user.delete();
      debugPrint('ACCOUNT DELETE SUCCESS');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AuthException(
          'Hesabını silmek için güvenlik nedeniyle şifreni tekrar girmelisin.',
          requiresReauth: true,
        );
      }
      throw AuthException(_mapDeleteAccountError(e));
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('ACCOUNT DELETE ERROR: $e');
      debugPrint(stackTrace.toString());
      throw AuthException('Hesap silinemedi. Lütfen tekrar deneyin.');
    }
  }

  static String _mapReauthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme yaptınız, biraz bekleyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı sorunu.';
      default:
        return 'Kimlik doğrulaması başarısız: ${e.code}';
    }
  }

  static String _mapDeleteAccountError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'Hesabını silmek için güvenlik nedeniyle şifreni tekrar girmelisin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı sorunu.';
      default:
        return 'Hesap silinemedi: ${e.code}';
    }
  }

  Future<AppUser> _loadUserProfile(User fbUser) async {
    final email = fbUser.email?.trim().toLowerCase() ?? '';
    final name = fbUser.displayName?.trim() ?? '';
    return TokenService.instance.ensureUserDocument(
      uid: fbUser.uid,
      name: name,
      email: email,
    );
  }

  static String mapFirebaseAuthError(
    FirebaseAuthException e, {
    bool login = false,
  }) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-posta zaten kayıtlı. Giriş yapmayı deneyin.';
      case 'invalid-email':
        return 'E-posta formatı hatalı.';
      case 'weak-password':
        return 'Şifre çok zayıf.';
      case 'too-many-requests':
        return 'Çok fazla deneme yaptınız, biraz bekleyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı sorunu.';
      case 'operation-not-allowed':
        return 'Firebase Console\'da Email/Password giriş yöntemi açık değil.';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return login ? 'E-posta veya şifre hatalı.' : 'Kimlik doğrulama hatası.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      default:
        return login ? 'Giriş hatası: ${e.code}' : 'Kayıt hatası: ${e.code}';
    }
  }
}
