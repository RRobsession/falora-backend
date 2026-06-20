import 'package:falora/auth/auth_service.dart';
import 'package:falora/auth/auth_validators.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/falora_logo_header.dart';
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
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await widget.authService.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        referralCode: _referralCtrl.text.trim().isEmpty
            ? null
            : _referralCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onRegistered(verificationEmailSent: true);
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
                              controller: _nameCtrl,
                              enabled: !_loading,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'İsim',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: AuthValidators.validateName,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailCtrl,
                              enabled: !_loading,
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
                              enabled: !_loading,
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
                                  onPressed: _loading
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
                              enabled: !_loading,
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
                                  onPressed: _loading
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
                              enabled: !_loading,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Davet Kodu (isteğe bağlı)',
                                prefixIcon: Icon(Icons.card_giftcard_outlined),
                              ),
                            ),
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
                                  : const Text('Hesap Oluştur'),
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
