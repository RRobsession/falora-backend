import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/config/app_branding.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Admin: tüm kayıtlı kullanıcılara özel bildirim.
class AdminBroadcastNotificationScreen extends StatefulWidget {
  const AdminBroadcastNotificationScreen({super.key});

  @override
  State<AdminBroadcastNotificationScreen> createState() =>
      _AdminBroadcastNotificationScreenState();
}

class _AdminBroadcastNotificationScreenState
    extends State<AdminBroadcastNotificationScreen> {
  final _titleCtrl = TextEditingController(text: appDisplayName);
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve metin gerekli')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm kullanıcılara gönder?'),
        content: Text(
          'Bu bildirim, push token’ı olan tüm kullanıcılara iletilir.\n\n'
          'Başlık: $title\n'
          'Metin: $body',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    try {
      final uri = Uri.parse('$apiBaseUrl/admin/broadcast-notification');
      final response = await http
          .post(
            uri,
            headers: await BackendAuthClient.authHeaders(),
            body: jsonEncode({'title': title, 'body': body}),
          )
          .timeout(const Duration(seconds: 120));

      BackendAuthClient.logRequest(
        '/admin/broadcast-notification',
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
              'Gönderilemedi (${response.statusCode})',
        );
      }

      final sent = json['sent'] ?? 0;
      final failed = json['failed'] ?? 0;
      final withToken = json['usersWithToken'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gönderildi: $sent · Başarısız: $failed · Token’lı kullanıcı: $withToken',
          ),
        ),
      );
      _bodyCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toplu bildirim'),
      ),
      body: FaloraBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Girdiğin başlık ve metin, uygulamada kayıtlı ve bildirim izni '
              'olan tüm kullanıcılara push olarak gider.',
              style: TextStyle(
                color: faloraTextSecondary,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 6,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Bildirim metni',
                hintText: 'Kullanıcılara gidecek mesaj…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.campaign_outlined),
              label: Text(_sending ? 'Gönderiliyor…' : 'Herkese gönder'),
            ),
          ],
        ),
      ),
    );
  }
}
