import 'package:falora/image_upload_card.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/services/problem_report_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/utils/upload_image_prepare.dart';
import 'package:falora/widgets/premium_ui.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gönderilemedi. Lütfen tekrar deneyin.'),
        ),
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
                    onPressed: busy
                        ? null
                        : () => _onImagePicked(null),
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
