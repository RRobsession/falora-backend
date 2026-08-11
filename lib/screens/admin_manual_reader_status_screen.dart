import 'package:falora/models/manual_fortune_reader.dart';
import 'package:falora/models/manual_reader_status.dart';
import 'package:falora/services/manual_reader_status_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/manual_fortune_reader_avatar.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

/// Admin: Serdar / Hatice durumunu ve müşteri görünürlüğünü ayarlar.
class AdminManualReaderStatusScreen extends StatefulWidget {
  const AdminManualReaderStatusScreen({super.key});

  @override
  State<AdminManualReaderStatusScreen> createState() =>
      _AdminManualReaderStatusScreenState();
}

class _AdminManualReaderStatusScreenState
    extends State<AdminManualReaderStatusScreen> {
  bool _savingId = false;
  String? _busyReaderId;

  Future<void> _setStatus(String readerId, ManualReaderStatus status) async {
    setState(() {
      _savingId = true;
      _busyReaderId = readerId;
    });
    try {
      await ManualReaderStatusService.instance.setStatus(
        readerId: readerId,
        status: status,
      );
      if (!mounted) return;
      final name =
          ManualReaderStatusService.instance.readerDisplayName(readerId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name → ${status.label}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Durum güncellenemedi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingId = false;
          _busyReaderId = null;
        });
      }
    }
  }

  Future<void> _setVisibility(String readerId, bool visible) async {
    setState(() {
      _savingId = true;
      _busyReaderId = readerId;
    });
    try {
      await ManualReaderStatusService.instance.setVisibility(
        readerId: readerId,
        visible: visible,
      );
      if (!mounted) return;
      final name =
          ManualReaderStatusService.instance.readerDisplayName(readerId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            visible
                ? '$name müşterilere tekrar görünür'
                : '$name müşterilerden gizlendi',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görünürlük güncellenemedi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingId = false;
          _busyReaderId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Falcı durumları'),
      ),
      body: FaloraBackground(
        child: StreamBuilder<ManualReaderStatusSnapshot>(
          stream: ManualReaderStatusService.instance.watch(),
          builder: (context, snap) {
            final statuses = snap.data ?? ManualReaderStatusSnapshot.empty;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text(
                  'Serdar ve Hatice için durumu manuel seç. '
                  '"Otomatik" dışındaki seçenekler yeni fal talebini durdurur. '
                  'Görünürlük kapalıysa falcı müşteri listesinden tamamen kalkar.',
                  style: TextStyle(
                    color: faloraTextSecondary,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                for (final reader in manualFortuneReaders) ...[
                  _ReaderStatusCard(
                    reader: reader,
                    status: statuses.forReader(reader.id),
                    visible: statuses.isVisible(reader.id),
                    busy: _savingId && _busyReaderId == reader.id,
                    onStatusChanged: (value) {
                      if (value == null) return;
                      _setStatus(reader.id, value);
                    },
                    onVisibilityChanged: (value) {
                      _setVisibility(reader.id, value);
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReaderStatusCard extends StatelessWidget {
  const _ReaderStatusCard({
    required this.reader,
    required this.status,
    required this.visible,
    required this.busy,
    required this.onStatusChanged,
    required this.onVisibilityChanged,
  });

  final ManualFortuneReader reader;
  final ManualReaderStatus status;
  final bool visible;
  final bool busy;
  final ValueChanged<ManualReaderStatus?> onStatusChanged;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: faloraParchmentDecoration(
        base: Color.lerp(faloraParchmentCard, reader.accentColor, 0.08)!,
        radius: FaloraRadius.lg,
        raised: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ManualFortuneReaderAvatar(
                reader: reader,
                size: 52,
                borderWidth: 2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reader.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: faloraInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reader.title,
                      style: const TextStyle(
                        color: faloraTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Müşterilere görünür',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: faloraInk,
              ),
            ),
            subtitle: Text(
              visible
                  ? 'Listede görünüyor; yeni talep alınabilir (duruma bağlı).'
                  : 'Listeden gizlendi; müşteriler seçemez.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: faloraTextSecondary,
              ),
            ),
            value: visible,
            onChanged: busy ? null : onVisibilityChanged,
          ),
          if (!visible) ...[
            const SizedBox(height: 4),
            Text(
              ManualReaderStatusService.hiddenMessage(reader.name),
              style: const TextStyle(
                color: faloraBronzeDark,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Durum',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ManualReaderStatus>(
                isExpanded: true,
                value: status,
                items: [
                  for (final option in manualReaderStatusOptions)
                    DropdownMenuItem(
                      value: option,
                      child: Text(option.label),
                    ),
                ],
                onChanged: busy ? null : onStatusChanged,
              ),
            ),
          ),
          if (!status.acceptsNewRequests) ...[
            const SizedBox(height: 10),
            Text(
              status.blockedMessage(reader.name),
              style: const TextStyle(
                color: faloraBronzeDark,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
