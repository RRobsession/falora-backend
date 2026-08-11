import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/utils/format_tokens.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Admin: e-posta ile kullanıcıya jeton yükleme.
class AdminGrantTokensScreen extends StatefulWidget {
  const AdminGrantTokensScreen({super.key});

  @override
  State<AdminGrantTokensScreen> createState() => _AdminGrantTokensScreenState();
}

class _AdminGrantTokensScreenState extends State<AdminGrantTokensScreen> {
  final _emailCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir e-posta girin')),
      );
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir jeton miktarı girin')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jeton yüklensin mi?'),
        content: Text(
          '$email adresine ${formatTokenAmount(amount)} jeton eklenecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yükle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$apiBaseUrl/admin/grant-tokens');
      final response = await http
          .post(
            uri,
            headers: await BackendAuthClient.authHeaders(),
            body: jsonEncode({'email': email, 'amount': amount}),
          )
          .timeout(const Duration(seconds: 30));

      BackendAuthClient.logRequest(
        '/admin/grant-tokens',
        statusCode: response.statusCode,
      );

      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (!mounted) return;
      if (response.statusCode != 200) {
        throw Exception(
          json['error']?.toString() ??
              'Yükleme başarısız (${response.statusCode})',
        );
      }

      final before = json['before'];
      final after = json['after'];
      final name = json['name']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${name.isEmpty ? email : name}: $before → $after '
            '(+${formatTokenAmount(amount)})',
          ),
        ),
      );
      _amountCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeton yükle'),
      ),
      body: FaloraBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Kullanıcının kayıtlı e-postasını girip jeton miktarını yaz. '
              'Bakiye anında artar.',
              style: TextStyle(
                color: faloraTextSecondary,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı e-postası',
                hintText: 'ornek@mail.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Jeton miktarı',
                hintText: '1500',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.monetization_on_outlined),
              label: Text(_loading ? 'Yükleniyor…' : 'Jeton yükle'),
            ),
          ],
        ),
      ),
    );
  }
}
