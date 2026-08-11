import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Admin: melek kartı cümlelerini 10/20’lik gruplara dağıtıp bildirir.
class AdminAngelCardsScreen extends StatefulWidget {
  const AdminAngelCardsScreen({super.key});

  @override
  State<AdminAngelCardsScreen> createState() => _AdminAngelCardsScreenState();
}

class _AdminAngelCardsScreenState extends State<AdminAngelCardsScreen> {
  static const _minCards = 2;
  static const _maxCards = 50;
  static const _defaultCardSlots = 7;

  final _titleCtrl = TextEditingController(text: 'Bugünün Melek Kartı');
  late final List<TextEditingController> _cardCtrls;
  int _groupSize = 10;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _cardCtrls = List.generate(
      _defaultCardSlots,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _cardCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  int get _slotCount => _cardCtrls.length;

  List<String> get _filledCards => _cardCtrls
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  void _setSlotCount(int count) {
    final next = count.clamp(_minCards, _maxCards);
    if (next == _cardCtrls.length) return;

    setState(() {
      if (next > _cardCtrls.length) {
        for (var i = _cardCtrls.length; i < next; i++) {
          _cardCtrls.add(TextEditingController());
        }
      } else {
        for (var i = _cardCtrls.length - 1; i >= next; i--) {
          _cardCtrls.removeAt(i).dispose();
        }
      }
    });
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final cards = _filledCards;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık gerekli')),
      );
      return;
    }
    if (cards.length < _minCards) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('En az $_minCards melek kartı cümlesi girin')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Melek kartları gönderilsin mi?'),
        content: Text(
          'Token’lı kullanıcılar karıştırılıp $_groupSize’şerli gruplara '
          'bölünecek.\n'
          'Her gruba sırayla farklı bir kart metni gidecek.\n\n'
          'Başlık: $title\n'
          'Dolu kart: ${cards.length} / $_slotCount alan\n'
          'Grup boyutu: $_groupSize',
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
      final uri = Uri.parse('$apiBaseUrl/admin/angel-cards');
      final response = await http
          .post(
            uri,
            headers: await BackendAuthClient.authHeaders(),
            body: jsonEncode({
              'title': title,
              'cards': cards,
              'groupSize': _groupSize,
            }),
          )
          .timeout(const Duration(seconds: 180));

      BackendAuthClient.logRequest(
        '/admin/angel-cards',
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
      final groups = json['groupCount'] ?? 0;
      final withToken = json['usersWithToken'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gönderildi: $sent · Başarısız: $failed · '
            'Grup: $groups · Token’lı: $withToken',
          ),
        ),
      );
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
    final filled = _filledCards.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Melek Kartı')),
      body: FaloraBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Kaç kart yazacağını seç (2–$_maxCards). Kullanıcılar karıştırılıp '
              'seçtiğin boyutta gruplara bölünür; her gruba sırayla farklı '
              'bir kart bildirimi gider. Boş bırakılan alanlar gönderilmez.',
              style: TextStyle(
                color: faloraTextSecondary,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              enabled: !_sending,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Bildirim başlığı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Grup boyutu',
              style: TextStyle(
                color: faloraInkHeading,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 10, label: Text('10’lu')),
                ButtonSegment(value: 20, label: Text('20’li')),
              ],
              selected: {_groupSize},
              onSelectionChanged: _sending
                  ? null
                  : (s) => setState(() => _groupSize = s.first),
            ),
            const SizedBox(height: 16),
            Text(
              'Kart alanı sayısı',
              style: TextStyle(
                color: faloraInkHeading,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _sending || _slotCount <= _minCards
                      ? null
                      : () => _setSlotCount(_slotCount - 1),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Alan azalt',
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$_slotCount alan',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: faloraInkHeading,
                        ),
                      ),
                      Text(
                        '$_minCards – $_maxCards arası',
                        style: TextStyle(
                          fontSize: 12,
                          color: faloraInkSoft.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _sending || _slotCount >= _maxCards
                      ? null
                      : () => _setSlotCount(_slotCount + 1),
                  icon: const Icon(Icons.add),
                  tooltip: 'Alan ekle',
                ),
              ],
            ),
            Slider(
              value: _slotCount.toDouble(),
              min: _minCards.toDouble(),
              max: _maxCards.toDouble(),
              divisions: _maxCards - _minCards,
              label: '$_slotCount',
              onChanged: _sending
                  ? null
                  : (v) => _setSlotCount(v.round()),
            ),
            const SizedBox(height: 8),
            Text(
              'Melek kartı cümleleri ($filled / $_slotCount dolu)',
              style: TextStyle(
                color: faloraInkHeading,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _cardCtrls.length; i++) ...[
              TextField(
                controller: _cardCtrls[i],
                enabled: !_sending,
                maxLines: 3,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Kart ${i + 1}',
                  hintText: i < _minCards
                      ? 'En az $_minCards kart doldurun'
                      : 'İsteğe bağlı — boş bırakılabilir',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'Dolu kart: $filled · Grup: $_groupSize kişi',
              style: TextStyle(
                color: faloraInkSoft.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_sending ? 'Gönderiliyor…' : 'Gruplara gönder'),
            ),
          ],
        ),
      ),
    );
  }
}
