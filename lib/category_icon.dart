import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Kategori ikonu: önce [iconPath] asset, yoksa [fallbackIcon].
class CategoryIconWidget extends StatelessWidget {
  const CategoryIconWidget({
    super.key,
    required this.iconPath,
    required this.fallbackIcon,
    required this.color,
    this.size = 44,
    this.iconSize = 24,
    this.hasGradient = false,
  });

  final String iconPath;
  final FaIconData fallbackIcon;
  final Color color;
  final double size;
  final double iconSize;
  final bool hasGradient;

  @override
  Widget build(BuildContext context) {
    final decoration = hasGradient
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4AF37), Color(0xFF8B6A3E)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFB8860B), width: 0.8),
          )
        : BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          );

    final iconColor = hasGradient ? const Color(0xFF2E2115) : color;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: decoration,
        child: Center(
          child: _buildIcon(iconColor),
        ),
      ),
    );
  }

  Widget _buildIcon(Color iconColor) {
    try {
      return SvgPicture.asset(
        iconPath,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        placeholderBuilder: (_) => FaIcon(
          fallbackIcon,
          size: iconSize - 2,
          color: iconColor,
        ),
      );
    } catch (_) {
      return FaIcon(fallbackIcon, size: iconSize - 2, color: iconColor);
    }
  }
}
