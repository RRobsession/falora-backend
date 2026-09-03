import 'dart:convert';

import 'package:falora/picked_image.dart';
import 'package:falora/models/manual_fortune_reader.dart';
import 'package:falora/models/manual_reader_status.dart';
import 'package:falora/services/manual_reader_status_service.dart';
import 'package:falora/services/manual_reader_profile_service.dart';
import 'package:falora/services/admin_reader_avatar_ai_service.dart';
import 'package:falora/utils/upload_image_prepare.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/manual_fortune_reader_avatar.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<void> _addReader() async {
    final name = TextEditingController();
    final title = TextEditingController();
    final bio = TextEditingController();
    PickedImage? photo;
    var gender = 'female';
    var generatingAvatar = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Yeni falcı ekle'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    maxLength: 50,
                    decoration: const InputDecoration(labelText: 'İsim'),
                  ),
                  TextField(
                    controller: title,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Kısa betimleyici',
                    ),
                  ),
                  TextField(
                    controller: bio,
                    maxLength: 300,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: const InputDecoration(labelText: 'Cinsiyet'),
                    items: const [
                      DropdownMenuItem(value: 'female', child: Text('Kadın')),
                      DropdownMenuItem(value: 'male', child: Text('Erkek')),
                      DropdownMenuItem(
                        value: 'unspecified',
                        child: Text('Belirtmek istemiyorum'),
                      ),
                    ],
                    onChanged: generatingAvatar
                        ? null
                        : (value) {
                            if (value != null) setLocal(() => gender = value);
                          },
                  ),
                  const SizedBox(height: 14),
                  if (photo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(
                        photo!.bytes,
                        width: 132,
                        height: 132,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: generatingAvatar
                              ? null
                              : () async {
                                  final file = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (file == null) return;
                                  photo = await prepareImageWithOptions(
                                    PickedImage(
                                      name: file.name,
                                      bytes: await file.readAsBytes(),
                                    ),
                                    const ImagePrepareOptions(
                                      maxEdge: 384,
                                      jpegQuality: 72,
                                      skipBelowBytes: 0,
                                    ),
                                  );
                                  setLocal(() {});
                                },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Kendim seçeyim'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: generatingAvatar
                              ? null
                              : () async {
                                  if (name.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'AI görseli için önce falcının ismini yazın.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setLocal(() => generatingAvatar = true);
                                  try {
                                    final bytes =
                                        await AdminReaderAvatarAiService
                                            .instance
                                            .generate(
                                              name: name.text,
                                              gender: gender,
                                              title: title.text,
                                            );
                                    photo = await prepareImageWithOptions(
                                      PickedImage(
                                        name: 'ai_reader_avatar.jpg',
                                        bytes: bytes,
                                      ),
                                      const ImagePrepareOptions(
                                        maxEdge: 384,
                                        jpegQuality: 76,
                                        skipBelowBytes: 0,
                                      ),
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'AI görseli oluşturulamadı: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setLocal(() => generatingAvatar = false);
                                    }
                                  }
                                },
                          icon: generatingAvatar
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            generatingAvatar
                                ? 'Oluşturuluyor…'
                                : 'AI oluştursun',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI seçeneği, uygulamanın sıcak ve mistik dünyasına uygun özgün bir profil görseli hazırlar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: faloraInkSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: generatingAvatar
                  ? null
                  : () => Navigator.pop(dialog, true),
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || title.text.trim().isEmpty) {
      return;
    }
    try {
      await ManualReaderProfileService.instance.add(
        name: name.text,
        title: title.text,
        bio: bio.text,
        gender: gender,
        avatarBase64: photo == null ? null : base64Encode(photo!.bytes),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Yeni falcı eklendi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falcı eklenemedi: $e')));
      }
    }
  }

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
      final name = ManualReaderStatusService.instance.readerDisplayName(
        readerId,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name → ${status.label}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Durum güncellenemedi: $e')));
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
      final name = ManualReaderStatusService.instance.readerDisplayName(
        readerId,
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Görünürlük güncellenemedi: $e')));
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
        actions: [
          IconButton(
            onPressed: _addReader,
            tooltip: 'Yeni falcı',
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: FaloraBackground(
        child: StreamBuilder<ManualReaderStatusSnapshot>(
          stream: ManualReaderStatusService.instance.watch(),
          builder: (context, snap) {
            final statuses = snap.data ?? ManualReaderStatusSnapshot.empty;
            return StreamBuilder<List<ManualFortuneReader>>(
              stream: ManualReaderProfileService.instance.watch(),
              initialData: manualFortuneReaders,
              builder: (context, readerSnap) {
                final readers = readerSnap.data ?? manualFortuneReaders;
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
                    for (final reader in readers) ...[
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
                    DropdownMenuItem(value: option, child: Text(option.label)),
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
