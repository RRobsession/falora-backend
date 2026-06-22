import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/auth/auth_service.dart';
import 'package:falora/auth/firebase_auth_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/falora_logo_header.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    required this.authService,
    required this.email,
    required this.onVerified,
    required this.onBackToLogin,
    this.showEmailSentMessage = false,
  });

  final AuthService authService;
  final String email;
  final VoidCallback onVerified;
  final VoidCallback onBackToLogin;
  final bool showEmailSentMessage;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const _emailSentMessage =
      'Doğrulama e-postası gönderildi. Gelen kutunu ve spam klasörünü kontrol et.';

  bool _checking = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    if (widget.showEmailSentMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEmailSentSnackBar();
      });
    }
  }

  void _showEmailSentSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(_emailSentMessage)),
    );
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw AuthException('Oturum bulunamadı.');
      }
      if (user.emailVerified) {
        widget.onVerified();
        return;
      }

      debugPrint('SEND VERIFICATION START');
      try {
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();
        debugPrint('SEND VERIFICATION SUCCESS');
      } on FirebaseAuthException catch (e) {
        debugPrint('SEND VERIFICATION ERROR: code=${e.code} message=${e.message}');
        throw AuthException(FirebaseAuthService.mapVerificationEmailError(e));
      }

      if (!mounted) return;
      _showEmailSentSnackBar();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      debugPrint('SEND VERIFICATION ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Doğrulama e-postası gönderilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }
  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      final verified = await widget.authService.reloadEmailVerificationStatus();
      if (!mounted) return;
      if (verified) {
        widget.onVerified();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta henüz doğrulanmamış.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Doğrulama kontrolü başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: faloraAuthBackground(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const FaloraLogoHeader(
                      compact: true,
                      subtitle: 'Hesabını güvence altına al',
                    ),
                    const SizedBox(height: 28),
                    AuthCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.mark_email_unread_outlined,
                            size: 48,
                            color: faloraGoldReadable,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'E-posta adresini doğrula',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: faloraTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sana doğrulama bağlantısı gönderdik. Mailini doğruladıktan sonra devam edebilirsin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: faloraTextSecondary.withValues(alpha: 0.92),
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: faloraInkHeading,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Mail gelmediyse spam klasörünü kontrol et.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: faloraTextSecondary.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: _checking ? null : _checkVerified,
                            child: _checking
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Doğruladım, Kontrol Et'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _resending ? null : _resend,
                            style: faloraOutlinedOnParchmentStyle(),
                            child: _resending
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: faloraBronzeDark,
                                    ),
                                  )
                                : const Text('Tekrar Gönder'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: widget.onBackToLogin,
                            child: const Text('Giriş ekranına dön'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
