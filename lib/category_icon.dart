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
              colors: [Color(0xFFE879A8), Color(0xFFA78BFA)],
            ),
            borderRadius: BorderRadius.circular(12),
          )
        : BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          );

    final iconColor = hasGradient ? Colors.white : color;

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
