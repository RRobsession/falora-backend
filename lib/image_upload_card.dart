import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/theme/falora_theme.dart';

const _card = faloraParchmentCard;
const _accent = faloraBronze;
const _textPrimary = faloraInk;
const _textSecondary = faloraInkSoft;

class ImageUploadCard extends StatelessWidget {
  const ImageUploadCard({
    super.key,
    required this.label,
    required this.image,
    required this.onChanged,
    this.icon = FontAwesomeIcons.image,
    this.accentColor = _accent,
  });

  final String label;
  final PickedImage? image;
  final ValueChanged<PickedImage?> onChanged;
  final FaIconData icon;
  final Color accentColor;

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dosya okunamadı. Lütfen başka bir görsel seçin.'),
          ),
        );
      }
      return;
    }

    onChanged(PickedImage(
      name: file.name,
      bytes: bytes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickFile(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasImage
                  ? accentColor.withValues(alpha: 0.6)
                  : faloraBronze.withValues(alpha: 0.35),
              width: hasImage ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    FaIcon(icon, color: accentColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (hasImage)
                      IconButton(
                        onPressed: () => onChanged(null),
                        icon: const Icon(Icons.close, size: 18),
                        color: _textSecondary,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Kaldır',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      image!.bytes,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    image!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textSecondary.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ] else ...[
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: faloraParchmentInset,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: faloraBronze.withValues(alpha: 0.35),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          color: accentColor.withValues(alpha: 0.8),
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dosya Seç',
                          style: TextStyle(
                            color: accentColor.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'JPG, PNG veya WEBP',
                          style: TextStyle(color: _textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
