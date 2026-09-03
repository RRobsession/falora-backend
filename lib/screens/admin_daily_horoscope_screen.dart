import 'package:falora/models/fortune_models.dart';
import 'package:falora/services/daily_horoscope_service.dart';
import 'package:falora/services/admin_editorial_ai_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

/// Admin: 12 burç için günlük yorum yazıp yayınlar.
class AdminDailyHoroscopeScreen extends StatefulWidget {
  const AdminDailyHoroscopeScreen({super.key});

  @override
  State<AdminDailyHoroscopeScreen> createState() =>
      _AdminDailyHoroscopeScreenState();
}

class _AdminDailyHoroscopeScreenState extends State<AdminDailyHoroscopeScreen>
    with WidgetsBindingObserver {
  final _controllers = <String, TextEditingController>{
    for (final z in burclar) z: TextEditingController(),
  };
  bool _loading = true;
  bool _publishing = false;
  bool _generating = false;
  late String _dateKey;

  String get _dateDisplay =>
      DailyHoroscopeService.formatDateKeyForDisplay(_dateKey);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dateKey = DailyHoroscopeService.istanbulDateKey();
    _loadDraft();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDateIfNeeded();
    }
  }

  void _refreshDateIfNeeded() {
    final today = DailyHoroscopeService.istanbulDateKey();
    if (today == _dateKey) return;
    setState(() => _dateKey = today);
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    setState(() => _loading = true);
    final draft = await DailyHoroscopeService.instance.loadAdminDraft(_dateKey);
    if (!mounted) return;
    if (draft != null) {
      for (final z in burclar) {
        _controllers[z]!.text = draft[z] ?? '';
      }
    } else {
      for (final z in burclar) {
        _controllers[z]!.clear();
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _publish({required bool sendNotifications}) async {
    final signs = <String, String>{};
    for (final z in burclar) {
      signs[z] = _controllers[z]!.text.trim();
    }
    final empty = burclar.where((z) => signs[z]!.isEmpty).toList();
    if (empty.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eksik burçlar: ${empty.join(', ')}')),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      final result = await DailyHoroscopeService.instance.publish(
        signs: signs,
        dateKey: _dateKey,
        sendNotifications: sendNotifications,
      );
      if (!mounted) return;
      final msg = sendNotifications
          ? 'Yayınlandı ($_dateDisplay). Bildirim: ${result.totalSent} gönderim.'
          : 'Kaydedildi ($_dateDisplay). Bildirim gönderilmedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _generateWithAi() async {
    setState(() => _generating = true);
    try {
      final result = await AdminEditorialAiService.instance.generate(
        type: 'horoscope',
        date: _dateKey,
      );
      final signs = Map<String, dynamic>.from(result['signs'] ?? const {});
      for (final sign in burclar) {
        final text = signs[sign]?.toString().trim() ?? '';
        if (text.isNotEmpty) _controllers[sign]!.text = text;
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Burç kutuları AI tarafından dolduruldu. Yayınlamadan önce kontrol et.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Günlük Burç ($_dateDisplay)'),
        actions: [
          TextButton.icon(
            onPressed: _publishing || _generating ? null : _generateWithAi,
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('AI oluştur'),
          ),
        ],
      ),
      body: FaloraBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  Text(
                    'Her burç için kısa bir günlük yorum yaz. '
                    'Gönderince kaydedilir ve o burçtaki kullanıcılara bildirim gider.',
                    style: TextStyle(
                      color: faloraTextSecondary,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final z in burclar) ...[
                    Text(
                      z,
                      style: FaloraTypography.titleLarge.copyWith(
                        fontSize: 16,
                        color: faloraInkHeading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controllers[z],
                      minLines: 6,
                      maxLines: 12,
                      maxLength: 4500,
                      decoration: InputDecoration(
                        hintText: '$z için kısa yorum...',
                        filled: true,
                        fillColor: faloraParchmentCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _publishing
                      ? null
                      : () => _publish(sendNotifications: false),
                  child: const Text('Sadece kaydet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _publishing
                      ? null
                      : () => _publish(sendNotifications: true),
                  child: _publishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kaydet ve bildir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
