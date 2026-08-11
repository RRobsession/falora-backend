import 'package:falora/auth/auth_service.dart';
import 'package:falora/auth/auth_validators.dart';
import 'package:falora/services/privacy_policy_service.dart';
import 'package:falora/services/terms_of_service_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/falora_logo_header.dart';
import 'package:falora/widgets/google_sign_in_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.authService,
    required this.onRegistered,
  });

  final AuthService authService;
  final void Function({bool verificationEmailSent}) onRegistered;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  bool get _busy => _loading || _googleLoading;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Devam etmek için 18 yaş onayını ve sözleşmeleri kabul etmelisiniz.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await widget.authService.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        referralCode: _referralCtrl.text.trim().isEmpty
            ? null
            : _referralCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onRegistered(
        verificationEmailSent: result.verificationEmailSent,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e, stackTrace) {
      debugPrint('Unknown register error: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Devam etmek için 18 yaş onayını ve sözleşmeleri kabul etmelisiniz.',
          ),
        ),
      );
      return;
    }

    setState(() => _googleLoading = true);
    try {
      await widget.authService.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onRegistered(verificationEmailSent: false);
    } on AuthException catch (e) {
      if (!mounted || e.userCancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e, stackTrace) {
      debugPrint('Unknown Google register error: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google ile kayıt hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
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
                      subtitle: 'Yeni bir yolculuğa başla',
                    ),
                    const SizedBox(height: 28),
                    AuthCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'E-posta',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: AuthValidators.validateEmail,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordCtrl,
                              enabled: !_busy,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                          setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: AuthValidators.validatePassword,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmCtrl,
                              enabled: !_busy,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                labelText: 'Şifre Tekrar',
                                prefixIcon: const Icon(Icons.lock_reset_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                            () => _obscureConfirm =
                                                !_obscureConfirm,
                                          ),
                                ),
                              ),
                              validator: (v) =>
                                  AuthValidators.validateConfirmPassword(
                                v,
                                _passwordCtrl.text,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _referralCtrl,
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Davet kodu (isteğe bağlı)',
                                helperText:
                                    'Şimdi veya sonra Profil → Arkadaşını Davet Et',
                                prefixIcon: Icon(Icons.card_giftcard_outlined),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _acceptedTerms,
                                  onChanged: _busy
                                      ? null
                                      : (value) => setState(
                                            () => _acceptedTerms = value ?? false,
                                          ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: _TermsAcceptanceText(
                                      enabled: !_busy,
                                      onOpenTerms: () => TermsOfServiceService
                                          .instance
                                          .openTermsOfService(context),
                                      onOpenPrivacy: () =>
                                          PrivacyPolicyService.instance
                                              .openPrivacyPolicy(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _busy ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Hesap Oluştur'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: faloraBronze.withValues(alpha: 0.35),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'veya',
                                    style: TextStyle(
                                      color: faloraInkSoft,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: faloraBronze.withValues(alpha: 0.35),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GoogleSignInButton(
                              loading: _googleLoading,
                              onPressed: _busy ? null : _signInWithGoogle,
                            ),
                          ],
                        ),
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

class _TermsAcceptanceText extends StatelessWidget {
  const _TermsAcceptanceText({
    required this.enabled,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool enabled;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: faloraInkSoft,
      fontSize: 13,
      height: 1.45,
    );
    const linkStyle = TextStyle(
      color: faloraBronze,
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: '18 yaşından büyüğüm, '),
          TextSpan(
            text: 'Kullanıcı Sözleşmesi',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = enabled ? onOpenTerms : null,
          ),
          const TextSpan(text: ' ve '),
          TextSpan(
            text: 'Gizlilik Politikasını',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = enabled ? onOpenPrivacy : null,
          ),
          const TextSpan(text: ' kabul ediyorum.'),
        ],
      ),
    );
  }
}
