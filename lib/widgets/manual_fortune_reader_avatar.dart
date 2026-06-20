import 'package:falora/models/manual_fortune_reader.dart';
import 'package:flutter/material.dart';

/// Yuvarlak çerçeveli manuel yorumcu illüstrasyon avatarı.
class ManualFortuneReaderAvatar extends StatelessWidget {
  const ManualFortuneReaderAvatar({
    super.key,
    required this.reader,
    this.size = 80,
    this.borderWidth = 2.5,
  });

  final ManualFortuneReader reader;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            reader.accentColor.withValues(alpha: 0.45),
            reader.accentColor.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: reader.accentColor.withValues(alpha: 0.65),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: reader.accentColor.withValues(alpha: 0.28),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.06),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: size * 0.12,
            offset: Offset(0, size * 0.03),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          reader.avatarAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
