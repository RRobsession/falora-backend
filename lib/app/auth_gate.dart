import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/auth/auth_service.dart';
import 'package:falora/config/admin_config.dart';
import 'package:falora/bulletin/bulletin_screens.dart';
import 'package:falora/main.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/screens/admin_home_screen.dart';
import 'package:falora/screens/login_screen.dart';
import 'package:falora/screens/onboarding/profile_onboarding_screen.dart';
import 'package:falora/screens/verification_screen.dart';
import 'package:falora/services/notification_service.dart';
import 'package:falora/services/referral_service.dart';
import 'package:falora/services/user_profile_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService});

  final AuthService? authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late final AuthService _authService =
      widget.authService ?? createAuthService();
  AppUser? _user;
  bool _firebaseEmailVerified = false;
  bool _loading = true;
  StreamSubscription<void>? _authSub;
  int _sessionGeneration = 0;
  bool _showVerificationSentMessage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = _authService.watchAuthState().listen((_) {
      _checkSession();
    });
    _checkSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSession();
    }
  }

  Future<void> _checkSession() async {
    final generation = ++_sessionGeneration;

    if (mounted && _user == null) {
      setState(() => _loading = true);
    }

    AppUser? user;
    try {
      user = await _authService.getCurrentUser().timeout(
        const Duration(seconds: 30),
      );
    } catch (e, stackTrace) {
      // Bir servis hatasi yukleme ekranini sonsuza kadar acik tutmamali.
      debugPrint('AUTH GATE SESSION CHECK FAILED: $e');
      debugPrint('$stackTrace');
    }
    if (!mounted || generation != _sessionGeneration) return;

    final fbUser = FirebaseAuth.instance.currentUser;
    final emailVerified = fbUser?.emailVerified ?? false;

    if (fbUser != null) {
      debugPrint('ADMIN UID: ${fbUser.uid}');
      debugPrint(
        'ADMIN CHECK: uidMatch=${adminUids.contains(fbUser.uid)} '
        'email=${fbUser.email} '
        'isAdmin=${isAdminUser(fbUser.uid, email: fbUser.email)}',
      );
    }

    if (!mounted || generation != _sessionGeneration) return;

    setState(() {
      _user = user;
      _firebaseEmailVerified = emailVerified;
      _loading = false;
    });

    if (user != null && emailVerified) {
      if (isCurrentFirebaseUserAdmin()) {
        unawaited(_runAdminPostAuthSetup(user.userId));
      } else {
        unawaited(_runPostAuthSetup(user.userId));
      }
    }
  }

  Future<void> _runAdminPostAuthSetup(String userId) async {
    try {
      // Admin panelinde ayrı bildirim ayarı ekranı yok. İzni burada isteyip
      // FCM token'ını kaydet ki uygulama kapalıyken admin push'ları ulaşsın.
      await NotificationService.instance.enableNotificationsForUser(userId);
    } catch (_) {}
  }

  Future<void> _runPostAuthSetup(String userId) async {
    try {
      await NotificationService.instance.registerForUser(userId);
    } catch (_) {}

    try {
      final notice = await ReferralService.instance
          .claimPendingReferralIfNeeded(userId);
      if (!mounted || notice == null || notice.isEmpty) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notice)));
    } catch (_) {
      debugPrint('REFERRAL_IGNORED_REGISTRATION_CONTINUES');
    }
  }

  void _onAuthenticated({bool verificationEmailSent = false}) {
    if (verificationEmailSent) {
      _showVerificationSentMessage = true;
    }
    _checkSession();
  }

  Future<void> _onLogout() async {
    final uid = _user?.userId;
    // Uzak FCM token temizligi cikisi bloke etmemeli. Firestore yavas veya
    // kullanilamaz olsa bile kullanici cihazdaki oturumunu kapatabilmeli.
    unawaited(
      NotificationService.instance
          .unregisterForUser(uid)
          .timeout(const Duration(seconds: 3))
          .catchError((Object e) {
            debugPrint('LOGOUT FCM CLEANUP SKIPPED: $e');
          }),
    );
    try {
      await _authService.logout().timeout(const Duration(seconds: 10));
    } catch (e, stackTrace) {
      debugPrint('LOGOUT ERROR: $e');
      debugPrint('$stackTrace');
    }
    if (!mounted) return;
    setState(() {
      _user = null;
      _loading = false;
    });
    // iOS'ta Fal alanı Bülten/Fal geçidinin üzerinde ayrı bir rota olarak
    // açılır. Oturum kapandıktan sonra bu rota kaldırılmazsa eski Fal ekranı
    // görünmeye devam eder ve çıkış yapılmamış izlenimi oluşturur.
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name != fortuneShellRouteName);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: FaloraBackground(
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: faloraBronze,
              ),
            ),
          ),
        ),
      );
    }

    if (_user == null) {
      return LoginScreen(
        authService: _authService,
        onLoggedIn: _onAuthenticated,
      );
    }

    if (!_firebaseEmailVerified) {
      final showSentMessage = _showVerificationSentMessage;
      if (showSentMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _showVerificationSentMessage = false);
          }
        });
      }

      return VerificationScreen(
        key: ValueKey(_user!.userId),
        authService: _authService,
        email: _user!.email,
        onVerified: _onAuthenticated,
        onBackToLogin: _onLogout,
        showEmailSentMessage: showSentMessage,
      );
    }

    if (isCurrentFirebaseUserAdmin()) {
      return AdminHomeScreen(onLogout: _onLogout);
    }

    if (UserProfileService.needsProfileCompletion(_user!)) {
      return ProfileOnboardingScreen(
        key: ValueKey('onboarding-${_user!.userId}'),
        user: _user!,
        onCompleted: _onAuthenticated,
      );
    }

    final verifiedUser = _user!.copyWith(emailVerified: true);
    if (usesIosExpandedExperience) {
      return IosProductGatewayScreen(
        onOpenFortune: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: fortuneShellRouteName),
            builder: (_) =>
                FaloraShell(user: verifiedUser, onLogout: _onLogout),
          ),
        ),
      );
    }
    return FaloraShell(user: verifiedUser, onLogout: _onLogout);
  }
}
