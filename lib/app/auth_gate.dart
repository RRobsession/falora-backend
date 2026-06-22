import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/auth/auth_service.dart';
import 'package:falora/config/admin_config.dart';
import 'package:falora/main.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/screens/admin_manual_fortune_screen.dart';
import 'package:falora/screens/login_screen.dart';
import 'package:falora/screens/verification_screen.dart';
import 'package:falora/services/notification_service.dart';
import 'package:falora/services/referral_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService});

  final AuthService? authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late final AuthService _authService = widget.authService ?? createAuthService();
  AppUser? _user;
  bool _firebaseEmailVerified = false;
  bool _loading = true;
  StreamSubscription<void>? _authSub;
  int _sessionGeneration = 0;
  bool _showVerificationSentMessage = false;
  String? _referralNotice;

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

    final user = await _authService.getCurrentUser();
    if (!mounted || generation != _sessionGeneration) return;

    final fbUser = FirebaseAuth.instance.currentUser;
    final emailVerified = fbUser?.emailVerified ?? false;

    if (fbUser != null) {
      debugPrint('ADMIN UID: ${fbUser.uid}');
    }

    if (user != null && emailVerified && !isAdminUser(user.userId)) {
      try {
        await NotificationService.instance.registerForUser(user.userId);
      } catch (_) {}
      try {
        final notice =
            await ReferralService.instance.claimPendingReferralIfNeeded(
          user.userId,
        );
        if (notice != null && notice.isNotEmpty) {
          _referralNotice = notice;
        }
      } catch (_) {
        debugPrint('REFERRAL_IGNORED_REGISTRATION_CONTINUES');
      }
    }

    if (!mounted || generation != _sessionGeneration) return;

    setState(() {
      _user = user;
      _firebaseEmailVerified = emailVerified;
      _loading = false;
    });
  }

  void _onAuthenticated({bool verificationEmailSent = false}) {
    if (verificationEmailSent) {
      _showVerificationSentMessage = true;
    }
    _checkSession();
  }

  Future<void> _onLogout() async {
    final uid = _user?.userId;
    await NotificationService.instance.unregisterForUser(uid);
    await _authService.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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

    if (isAdminUser(_user!.userId)) {
      return AdminManualRequestsScreen(onLogout: _onLogout);
    }

    final referralNotice = _referralNotice;
    _referralNotice = null;

    return FaloraShell(
      user: _user!.copyWith(emailVerified: true),
      onLogout: _onLogout,
      initialSnackBarMessage: referralNotice,
    );
  }
}
