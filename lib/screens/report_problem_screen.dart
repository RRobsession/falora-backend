import 'package:falora/image_upload_card.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/models/problem_report.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/services/problem_report_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/utils/upload_image_prepare.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:falora/widgets/support_message_bubble.dart';
import 'package:flutter/material.dart';

/// Profil → Sorun bildir.
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _descriptionCtrl = TextEditingController();
  PickedImage? _image;
  PickedImage? _preparedImage;
  bool _preparingImage = false;
  bool _submitting = false;
  String _statusText = '';
  int _imageGen = 0;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _onImagePicked(PickedImage? raw) async {
    final gen = ++_imageGen;
    if (raw == null) {
      setState(() {
        _image = null;
        _preparedImage = null;
        _preparingImage = false;
      });
      return;
    }

    setState(() {
      _image = raw;
      _preparedImage = null;
      _preparingImage = true;
    });

    try {
      final prepared = await prepareProblemReportImageForUpload(raw);
      if (!mounted || gen != _imageGen) return;
      setState(() {
        _preparedImage = prepared;
        // Önizlemede de küçültülmüş görseli göster (bellek + akıcılık).
        _image = prepared;
        _preparingImage = false;
      });
    } catch (_) {
      if (!mounted || gen != _imageGen) return;
      setState(() {
        _preparedImage = raw;
        _preparingImage = false;
      });
    }
  }

  Future<void> _submit() async {
    final text = _descriptionCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen yaşadığınız sorunu yazın.')),
      );
      return;
    }
    if (_preparingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görsel hâlâ hazırlanıyor, bir saniye…')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _statusText = 'Gönderiliyor…';
    });
    // Loading UI'nin boyanması için.
    await Future<void>.delayed(Duration.zero);

    try {
      final user = widget.user;
      await ProblemReportService.instance.createReport(
        userId: user.userId,
        userEmail: user.email,
        displayName: user.effectiveDisplayName,
        description: text,
        platform: ProblemReportService.detectPlatform(),
        image: _preparedImage ?? _image,
        imageAlreadyPrepared: _preparedImage != null,
        onPhase: (phase) {
          if (!mounted) return;
          setState(() => _statusText = phase);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sorununuz iletildi. Teşekkürler.')),
      );
      Navigator.of(context).pop();
    } on ProblemReportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gönderilemedi. Lütfen tekrar deneyin.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _statusText = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _preparingImage;

    return Scaffold(
      appBar: AppBar(title: const Text('Sorun Bildir')),
      body: FaloraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              StreamBuilder<List<ProblemReport>>(
                stream: ProblemReportService.instance.watchOpenForUser(
                  widget.user.userId,
                ),
                builder: (context, snapshot) {
                  final reports = snapshot.data ?? const [];
                  if (reports.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Açık destek görüşmelerim',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final report in reports)
                        _SupportConversationCard(report: report),
                      const Divider(height: 32),
                    ],
                  );
                },
              ),
              Text(
                'Karşılaştığınız sorunu kısaca yazın. İsterseniz bir ekran '
                'görüntüsü de ekleyebilirsiniz.',
                style: TextStyle(
                  color: faloraInkSoft,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _descriptionCtrl,
                enabled: !_submitting,
                maxLines: 8,
                maxLength: ProblemReportService.maxDescriptionLength,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: 'Sorun açıklaması',
                  hintText: 'Ne oldu? Ne bekliyordunuz?',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: faloraParchmentCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ImageUploadCard(
                label: _preparingImage
                    ? 'Görsel hazırlanıyor…'
                    : _image == null
                    ? 'Ekran görüntüsü ekle (isteğe bağlı)'
                    : 'Ekran görüntüsü seçildi',
                image: _image,
                onChanged: _submitting ? (_) {} : _onImagePicked,
              ),
              if (_image != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : () => _onImagePicked(null),
                    child: const Text('Görseli kaldır'),
                  ),
                ),
              ],
              if (_statusText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: faloraInkSoft.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gönder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportConversationCard extends StatefulWidget {
  const _SupportConversationCard({required this.report});
  final ProblemReport report;

  @override
  State<_SupportConversationCard> createState() =>
      _SupportConversationCardState();
}

class _SupportConversationCardState extends State<_SupportConversationCard> {
  bool _sending = false;

  Future<void> _reply() async {
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: faloraInkMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Destek ekibine yanıtla',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'Mesajın bu destek görüşmesine eklenecek.',
              style: TextStyle(color: faloraInkSoft, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 1500,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Mesajın',
                hintText: 'Eklemek istediğin ayrıntıları yaz…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(sheetContext, value);
              },
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Yanıtı gönder'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;

    setState(() => _sending = true);
    try {
      await ProblemReportService.instance.sendMessage(
        reportId: widget.report.id,
        text: text,
        admin: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yanıtın destek ekibine gönderildi.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yanıt gönderilemedi. Lütfen tekrar dene.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: faloraParchmentDecoration(
      radius: FaloraRadius.lg,
      raised: true,
    ),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: faloraGold.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.support_agent_rounded, color: faloraBronzeDark),
      ),
      title: Text(
        widget.report.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF4F8A5B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text('Görüşme açık'),
          ],
        ),
      ),
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: ProblemReportService.instance.watchMessages(widget.report.id),
          builder: (context, snapshot) {
            final messages = snapshot.data ?? const [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (messages.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: faloraParchmentInset,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Henüz mesaj yok. Yeni bir ayrıntı ekleyebilir veya destek ekibinin yanıtını bekleyebilirsin.',
                      style: TextStyle(color: faloraInkSoft, height: 1.35),
                    ),
                  ),
                for (final message in messages)
                  SupportMessageBubble(
                    message: message,
                    viewerIsAdmin: false,
                  ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: _sending ? null : _reply,
                  icon: _sending
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.reply_rounded, size: 19),
                  label: Text(_sending ? 'Gönderiliyor…' : 'Yanıt yaz'),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
