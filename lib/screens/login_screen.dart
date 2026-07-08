import 'package:falora/auth/auth_service.dart';
import 'package:falora/auth/auth_validators.dart';
import 'package:falora/screens/register_screen.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/falora_logo_header.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.onLoggedIn,
  });

  final AuthService authService;
  final void Function({bool verificationEmailSent}) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _showForgotPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint('LOGIN BUTTON CLICKED');

    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    debugPrint('LOGIN START');
    debugPrint('LOGIN EMAIL: $email');

    setState(() => _loading = true);
    try {
      await widget.authService.login(
        email: email,
        password: password,
      );
      if (!mounted) return;
      setState(() => _showForgotPassword = false);
      widget.onLoggedIn();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _showForgotPassword = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e, stackTrace) {
      debugPrint('Unknown login error: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() => _showForgotPassword = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Giriş hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRegister() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          authService: widget.authService,
          onRegistered: widget.onLoggedIn,
        ),
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim();
    final emailError = AuthValidators.validateEmail(email);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce geçerli e-posta adresinizi girin.'),
        ),
      );
      return;
    }

    try {
      await widget.authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$email adresine şifre sıfırlama bağlantısı gönderildi.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şifre sıfırlama hatası: $e')),
      );
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
                      subtitle: 'Kadim bilgelik, kişisel rehberlik',
                    ),
                    const SizedBox(height: 36),
                    AuthCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Giriş Yap',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: faloraTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Fallarına kaldığın yerden devam et',
                              style: TextStyle(
                                color: faloraTextSecondary.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailCtrl,
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
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: AuthValidators.validatePassword,
                            ),
                            if (_showForgotPassword) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _loading ? null : _sendPasswordReset,
                                  style: TextButton.styleFrom(
                                    foregroundColor: faloraBronzeDark,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Şifreni mi unuttun?'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Giriş Yap'),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _loading ? null : _openRegister,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: faloraBronzeDark,
                                side: BorderSide(
                                  color: faloraBronze.withValues(alpha: 0.6),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Kayıt Ol'),
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
