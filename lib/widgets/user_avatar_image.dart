import 'dart:convert';
import 'dart:typed_data';

import 'package:falora/config/avatar_catalog.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';

/// Profil görseli — preset asset veya galeri (custom base64).
class UserAvatarImage extends StatelessWidget {
  const UserAvatarImage({
    super.key,
    this.avatarAsset,
    this.size = 56,
    this.fit = BoxFit.cover,
    this.fallbackInitial,
    this.showLoadErrorSnackBar = false,
  });

  final String? avatarAsset;
  final double size;
  final BoxFit fit;
  final String? fallbackInitial;
  final bool showLoadErrorSnackBar;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final raw = avatarAsset?.trim();
    if (raw != null && isCustomAvatarAsset(raw)) {
      final bytes = decodeCustomAvatarBytes(raw);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: fit,
          width: size,
          height: size,
          errorBuilder: (ctx, _, __) => _onLoadError(ctx),
        );
      }
      return _emptyFrame();
    }

    final asset = resolvePresetAvatarAssetPath(raw);
    if (asset == null) {
      return _emptyFrame();
    }

    return Image.asset(
      asset,
      fit: fit,
      width: size,
      height: size,
      gaplessPlayback: true,
      errorBuilder: (ctx, _, __) => _onLoadError(ctx),
    );
  }

  Widget _onLoadError(BuildContext context) {
    if (showLoadErrorSnackBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Avatar yüklenemedi')),
        );
      });
    }
    return _emptyFrame();
  }

  /// Boş premium çerçeve — ikon yok, parent SizedBox boyutunu doldurur.
  Widget _emptyFrame() {
    return ColoredBox(
      color: faloraParchmentRaised,
      child: fallbackInitial != null && fallbackInitial!.trim().isNotEmpty
          ? Center(
              child: Text(
                fallbackInitial!.trim().substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w800,
                  color: faloraInkSoft,
                ),
              ),
            )
          : null,
    );
  }
}

/// Grid / picker avatar önizlemesi — altın çerçeve, glow, tik.
class PresetAvatarThumbnail extends StatelessWidget {
  const PresetAvatarThumbnail({
    super.key,
    required this.assetPath,
    this.size = 80,
    this.selected = false,
  });

  final String assetPath;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: selected ? faloraGoldDark : faloraBronze.withValues(alpha: 0.35),
          width: selected ? 3 : 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: faloraGold.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [
                BoxShadow(
                  color: faloraBronzeDark.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: faloraParchmentRaised,
              ),
            ),
            if (selected)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: faloraGoldDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: faloraParchmentRaised, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: faloraGold.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: faloraParchmentRaised,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const customAvatarPrefix = 'custom:';

bool isCustomAvatarAsset(String? value) =>
    value != null && value.startsWith(customAvatarPrefix);

Uint8List? decodeCustomAvatarBytes(String value) {
  if (!isCustomAvatarAsset(value)) return null;
  try {
    return base64Decode(value.substring(customAvatarPrefix.length));
  } catch (_) {
    return null;
  }
}

String encodeCustomAvatarBytes(Uint8List bytes) =>
    '$customAvatarPrefix${base64Encode(bytes)}';
