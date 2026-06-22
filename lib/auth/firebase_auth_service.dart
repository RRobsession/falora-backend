import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/auth/auth_service.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/services/fortune_storage_service.dart';
import 'package:falora/services/manual_fortune_storage_service.dart';
import 'package:falora/services/referral_service.dart';
import 'package:falora/services/notification_service.dart';
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
    debugPrint('EMAIL_VERIFICATION_SEND_START');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('EMAIL_VERIFICATION_SEND_FAILED: currentUser is null');
      throw AuthException('Oturum bulunamadı, doğrulama e-postası gönderilemedi.');
    }

    debugPrint('EMAIL_VERIFICATION_SEND uid: ${user.uid}');
    if (kDebugMode) {
      debugPrint('EMAIL_VERIFICATION_SEND email present: ${user.email != null}');
    }

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      debugPrint('EMAIL_VERIFICATION_SEND_SUCCESS');
    } on FirebaseAuthException catch (e) {
      debugPrint('EMAIL_VERIFICATION_SEND_FAILED: code=${e.code} message=${e.message}');
      throw AuthException(mapVerificationEmailError(e));
    } catch (e, stackTrace) {
      debugPrint('EMAIL_VERIFICATION_SEND_FAILED: $e');
      debugPrint(stackTrace.toString());
      throw AuthException('Doğrulama e-postası gönderilemedi: $e');
    }
  }

  Future<void> _rollbackNewAuthAccount(User? user) async {
    if (user == null) return;
    debugPrint('REGISTER_AUTH_ROLLBACK_DELETE_START');
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
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    debugPrint('REGISTER START');
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

      try {
        debugPrint('REGISTER_USER_DOC_CREATE_START uid: $uid');
        await TokenService.instance.ensureUserDocument(
          uid: uid,
          name: name.trim(),
          email: normalizedEmail,
        );
        debugPrint('REGISTER_USER_DOC_CREATE_SUCCESS uid: $uid');

        if (referralCode != null && referralCode.trim().isNotEmpty) {
          ReferralService.instance.storePendingReferralCode(uid, referralCode);
        }

        await _sendVerificationEmailToCurrentUser();
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

      return AppUser(
        userId: uid,
        name: name.trim(),
        email: normalizedEmail,
        tokens: initialUserTokens,
        emailVerified: false,
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
    debugPrint('CHECK VERIFY START');

    final before = FirebaseAuth.instance.currentUser;
    if (before == null) {
      debugPrint('VERIFY FAILED (no user)');
      throw AuthException('Oturum bulunamadı.');
    }

    debugPrint('BEFORE RELOAD emailVerified: ${before.emailVerified}');

    await FirebaseAuth.instance.currentUser?.reload();

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

    debugPrint('VERIFY SUCCESS');
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
