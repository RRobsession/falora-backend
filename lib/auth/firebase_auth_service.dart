import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/auth/email_verification_helper.dart' as email_verification;
import 'package:falora/auth/auth_service.dart';
import 'package:falora/auth/google_sign_in_config.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/services/fortune_storage_service.dart';
import 'package:falora/services/manual_fortune_storage_service.dart';
import 'package:falora/services/referral_service.dart';
import 'package:falora/services/notification_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/token_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService._();

  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void>? _googleInitFuture;

  /// google_sign_in 7.x — yalnızca bir kez çağrılmalı (main.dart).
  static Future<void> initializeGoogleSignIn() {
    _googleInitFuture ??= _configureGoogleSignIn();
    return _googleInitFuture!;
  }

  static Future<void> _configureGoogleSignIn() async {
    debugPrint('GOOGLE_SIGN_IN_INIT_START web=$kIsWeb');
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? googleSignInWebClientId : null,
      serverClientId: kIsWeb ? null : googleSignInServerClientId,
    );
    debugPrint('GOOGLE_SIGN_IN_INIT_SUCCESS');
  }

  Future<void> _ensureGoogleSignInReady() async {
    await initializeGoogleSignIn();
  }

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

    // Uygulama acilisini ag hatasina baglama. Firebase Auth yenilemesi bazen
    // cevap vermeden bekleyebiliyor; cihazdaki gecerli oturumu kullanmaya devam
    // ederek kullaniciyi sonsuz yukleme ekraninda birakma.
    try {
      await FirebaseAuth.instance.currentUser?.reload().timeout(
        const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('AUTH RELOAD SKIPPED, USING CACHED SESSION: $e');
      return FirebaseAuth.instance.currentUser ?? before;
    }

    final after = FirebaseAuth.instance.currentUser;
    if (logPrefix != null && after != null) {
      debugPrint('$logPrefix AFTER RELOAD emailVerified: ${after.emailVerified}');
    }

    return after;
  }

  Future<void> _sendVerificationEmailToCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('Oturum bulunamadı.');
    }
    await email_verification.sendAppEmailVerification(user);
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
    final ref = _db.collection('users').doc(uid);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        debugPrint(
          'Firestore emailVerified sync skipped (user doc missing) uid=$uid',
        );
        return;
      }
      await ref.update({
        'emailVerified': true,
        'emailVerifiedAt': FieldValue.serverTimestamp(),
      });
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

    try {
      final profile = await _loadUserProfile(
        fbUser,
      ).timeout(const Duration(seconds: 10));
      if (emailVerified) {
        await _syncEmailVerifiedToFirestore(
          fbUser.uid,
        ).timeout(const Duration(seconds: 6));
      }
      return _appUserFromFirebaseAndFirestore(fbUser, profile);
    } catch (e, stackTrace) {
      debugPrint('Firestore user fetch failed: $e');
      debugPrint(stackTrace.toString());
      try {
        final recovered = await TokenService.instance
            .ensureUserDocument(
              uid: fbUser.uid,
              name: fbUser.displayName?.trim() ?? '',
              email: fbUser.email?.trim().toLowerCase() ?? '',
            )
            .timeout(const Duration(seconds: 8));
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

      try {
        final profile = await _loadUserProfile(fbUser);
        if (fbUser.emailVerified) {
          await _syncEmailVerifiedToFirestore(fbUser.uid);
        }
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
  Future<AppUser> signInWithGoogle() async {
    debugPrint('GOOGLE_SIGN_IN_START web=$kIsWeb');
    try {
      await _ensureGoogleSignInReady();

      // Önceki oturumu temizle (Chrome’da admin oturumu kalmasın).
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      await _auth.signOut();

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        final credential = await _auth.signInWithPopup(provider);
        final fbUser = credential.user;
        if (fbUser == null) {
          throw AuthException('Google ile giriş tamamlanamadı.');
        }
        debugPrint(
          'GOOGLE_SIGN_IN_ACCOUNT uid=${fbUser.uid} email=${fbUser.email}',
        );
        return _completeGoogleSignIn(fbUser);
      }

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw AuthException(
          'Bu cihazda Google ile giriş şu an desteklenmiyor.',
        );
      }

      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );

      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw AuthException(
          'Google kimlik doğrulaması tamamlanamadı. Lütfen tekrar deneyin.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);

      final fbUser = await _reloadCurrentUser(logPrefix: 'GOOGLE');
      if (fbUser == null) {
        throw AuthException('Google ile giriş tamamlanamadı.');
      }
      debugPrint(
        'GOOGLE_SIGN_IN_ACCOUNT uid=${fbUser.uid} email=${fbUser.email}',
      );
      return _completeGoogleSignIn(fbUser);
    } on AuthException {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (_isGoogleSignInCancellation(e)) {
        debugPrint('GOOGLE_SIGN_IN_CANCELLED code=${e.code.name}');
        throw AuthException('', userCancelled: true);
      }
      debugPrint(
        'GOOGLE_SIGN_IN_ERROR code=${e.code.name} desc=${e.description}',
      );
      throw AuthException(mapGoogleSignInError(e));
    } on FirebaseAuthException catch (e) {
      if (_isFirebaseGoogleSignInCancellation(e)) {
        debugPrint('GOOGLE_SIGN_IN_CANCELLED firebase code=${e.code}');
        throw AuthException('', userCancelled: true);
      }
      debugPrint('GOOGLE_FIREBASE_AUTH_ERROR code=${e.code}');
      throw AuthException(mapFirebaseAuthError(e, login: true));
    } catch (e, stackTrace) {
      debugPrint('GOOGLE_SIGN_IN_UNKNOWN_ERROR: $e');
      debugPrint(stackTrace.toString());
      throw AuthException('Google ile giriş yapılamadı. Lütfen tekrar deneyin.');
    }
  }

  Future<AppUser> _completeGoogleSignIn(User fbUser) async {
    debugPrint(
      'GOOGLE_SIGN_IN_SUCCESS uid=${fbUser.uid} '
      'emailVerified=${fbUser.emailVerified}',
    );

    final email = fbUser.email?.trim().toLowerCase() ?? '';
    final displayName = fbUser.displayName?.trim() ?? '';
    final photoUrl = fbUser.photoURL;

    AppUser profile;
    try {
      profile = await TokenService.instance.syncGoogleUserDocument(
        uid: fbUser.uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
      );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('GOOGLE_USER_DOC_SYNC_FAILED code=${e.code}');
      debugPrint(stackTrace.toString());
      final message = e.code == 'permission-denied'
          ? 'Profil kaydı tamamlanamadı (veritabanı izni).'
          : 'Google profili kaydedilemedi. Lütfen tekrar deneyin.';
      throw AuthException(message);
    }

    if (fbUser.emailVerified) {
      await _syncEmailVerifiedToFirestore(fbUser.uid);
    }

    return _appUserFromFirebaseAndFirestore(
      fbUser,
      profile.copyWith(emailVerified: true),
    );
  }

  static bool _isFirebaseGoogleSignInCancellation(FirebaseAuthException e) {
    switch (e.code) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return true;
      default:
        return false;
    }
  }

  static bool _isGoogleSignInCancellation(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return true;
      case GoogleSignInExceptionCode.interrupted:
      case GoogleSignInExceptionCode.uiUnavailable:
      case GoogleSignInExceptionCode.unknownError:
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
      case GoogleSignInExceptionCode.userMismatch:
        return false;
    }
  }

  static String mapGoogleSignInError(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return '';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google girişi yarıda kesildi. Lütfen tekrar deneyin.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google giriş ekranı açılamadı. Lütfen tekrar deneyin.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google girişi yapılandırılmamış. Lütfen daha sonra tekrar deneyin.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Google hesabı oturumu karıştı. Lütfen tekrar deneyin.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Google ile giriş yapılamadı. Lütfen tekrar deneyin.';
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = _normalizeEmail(email);
    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (e) {
      throw AuthException(mapFirebaseAuthError(e));
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
    // Firebase oturumu yerel olarak once kapatilir. Google veya ag temizligi
    // gecikse bile kullanici uygulamada oturum acik kalmaz.
    await _auth.signOut().timeout(const Duration(seconds: 5));
    try {
      await GoogleSignIn.instance.signOut().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('GOOGLE_SIGN_OUT_ERROR: $e');
    }
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
      case 'account-exists-with-different-credential':
        return 'Bu e-posta farklı bir giriş yöntemiyle kayıtlı. E-posta/şifre ile deneyin.';
      default:
        return login ? 'Giriş hatası: ${e.code}' : 'Kayıt hatası: ${e.code}';
    }
  }
}
