import 'dart:math' as math;

import 'package:falora/theme/falora_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Parşömen kağıt dokusu — hafif leke ve yaşlanma hissi.
BoxDecoration faloraParchmentDecoration({
  Color base = faloraParchmentCard,
  double radius = FaloraRadius.lg,
  bool raised = true,
  bool goldBorder = true,
  double borderWidth = 1.2,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: raised
          ? [
              faloraParchmentRaised,
              base,
              faloraParchmentInset,
            ]
          : [
              base,
              faloraParchmentMid,
            ],
      stops: raised ? const [0.0, 0.45, 1.0] : const [0.0, 1.0],
    ),
    border: goldBorder
        ? Border.all(
            color: faloraGold.withValues(alpha: 0.75),
            width: borderWidth,
          )
        : Border.all(
            color: faloraBronze.withValues(alpha: 0.25),
            width: 1,
          ),
    boxShadow: raised
        ? [
            BoxShadow(
              color: faloraBronzeDark.withValues(alpha: 0.22),
              offset: const Offset(2, 3),
              blurRadius: 0,
            ),
            BoxShadow(
              color: faloraInk.withValues(alpha: 0.06),
              offset: const Offset(0, 6),
              blurRadius: 12,
            ),
          ]
        : null,
  );
}

/// Eski cam kart API'si — parşömen sistemine yönlendirilir.
BoxDecoration faloraGlassDecoration({
  Color accent = faloraBronze,
  double radius = FaloraRadius.xl,
  double opacity = 0.14,
}) {
  return faloraParchmentDecoration(
    base: Color.lerp(faloraParchmentCard, accent, opacity * 0.35)!,
    radius: radius,
    raised: true,
    goldBorder: true,
  );
}

/// Kitap sayfası arka planı.
class FaloraParchmentBackground extends StatelessWidget {
  const FaloraParchmentBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            faloraParchmentLight,
            faloraParchmentMid,
            faloraParchmentDeep,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ParchmentVeinPainter(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ParchmentVeinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = faloraBronzeDark.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.25,
        size.width * 0.5,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.12,
        size.width * 0.9,
        size.height * 0.22,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Altın çerçeveli parşömen kart.
class FaloraParchmentCard extends StatelessWidget {
  const FaloraParchmentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FaloraSpacing.lg),
    this.margin,
    this.accent = faloraBronze,
    this.ornament,
    this.onTap,
    this.raised = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color accent;
  final Widget? ornament;
  final VoidCallback? onTap;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: faloraParchmentDecoration(
        base: Color.lerp(faloraParchmentCard, accent, 0.06)!,
        raised: raised,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (ornament != null)
            Positioned(top: 8, right: 10, child: ornament!),
          child,
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FaloraRadius.lg),
        child: card,
      ),
    );
  }
}

/// İnce altın köşe süsü.
class FaloraCornerOrnament extends StatelessWidget {
  const FaloraCornerOrnament({super.key, this.size = 18, this.color = faloraGold});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CornerOrnamentPainter(color: color),
    );
  }
}

class _CornerOrnamentPainter extends CustomPainter {
  _CornerOrnamentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..lineTo(0, 0)
      ..lineTo(size.width * 0.35, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bölüm başlığı — el yazması kitap stili.
class FaloraSectionTitle extends StatelessWidget {
  const FaloraSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: faloraGold.withValues(alpha: 0.6)),
              color: faloraParchmentInset.withValues(alpha: 0.5),
            ),
            child: Icon(icon, size: 16, color: faloraBronzeDark),
          ),
          const SizedBox(width: FaloraSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FaloraTypography.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: FaloraTypography.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ana CTA — bronz mürekkep, altın çerçeve.
class FaloraPrimaryButton extends StatelessWidget {
  const FaloraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(FaloraRadius.md),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FaloraRadius.md),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [faloraBronze, faloraBronzeDark],
            ),
            border: Border.all(color: faloraGold, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: faloraBronzeDark.withValues(alpha: 0.28),
                offset: const Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: faloraParchmentRaised,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: faloraParchmentRaised),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: FaloraTypography.labelLarge.copyWith(
                          color: faloraParchmentRaised,
                          fontSize: 15,
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 10),
                        trailing!,
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Jeton rozeti — pirinç/altın madeni para hissi.
class FaloraTokenBadge extends StatelessWidget {
  const FaloraTokenBadge({
    super.key,
    required this.amount,
    this.compact = false,
  });

  final int amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: faloraParchmentInset.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: faloraGold.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.coins,
            size: compact ? 12 : 13,
            color: faloraGoldDark,
          ),
          const SizedBox(width: 6),
          Text(
            '$amount jeton',
            style: FaloraTypography.labelLarge.copyWith(
              color: faloraInk,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// İnce mürekkep ayırıcı — kitap bölüm çizgisi.
class FaloraInkDivider extends StatelessWidget {
  const FaloraInkDivider({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: FaloraSpacing.md),
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            faloraBronze.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Kategori hero şeridi — tarot salonu / rüya / numeroloji / burç.
class FaloraCategoryHeroStrip extends StatelessWidget {
  const FaloraCategoryHeroStrip({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.symbol,
    this.tokenCost,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Widget? symbol;
  final int? tokenCost;

  @override
  Widget build(BuildContext context) {
    return FaloraParchmentCard(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      ornament: const FaloraCornerOrnament(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (symbol != null) ...[
            symbol!,
            const SizedBox(height: FaloraSpacing.md),
          ],
          Text(
            title,
            style: FaloraTypography.displayMedium.copyWith(color: faloraInk),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: FaloraTypography.bodyLarge),
          if (tokenCost != null) ...[
            const SizedBox(height: FaloraSpacing.md),
            FaloraTokenBadge(amount: tokenCost!, compact: true),
          ],
        ],
      ),
    );
  }
}

/// Parşömen üzerindeki OutlinedButton stili — okunabilir kontrast.
ButtonStyle faloraOutlinedOnParchmentStyle({
  EdgeInsetsGeometry? padding,
}) {
  return OutlinedButton.styleFrom(
    foregroundColor: faloraBronzeDark,
    side: BorderSide(color: faloraBronze.withValues(alpha: 0.6), width: 1.2),
    padding: padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    textStyle: FaloraTypography.labelLarge.copyWith(
      color: faloraBronzeDark,
      fontSize: 14,
    ),
  );
}


enum FaloraReadingStatus { ready, preparing, pending }

/// Soluk mühür — Hazır / Hazırlanıyor / Beklemede (dikkat dağıtmaz).
class FaloraStatusSeal extends StatelessWidget {
  const FaloraStatusSeal({
    super.key,
    required this.status,
    this.label,
  });

  final FaloraReadingStatus status;
  final String? label;

  String get _defaultLabel => switch (status) {
        FaloraReadingStatus.ready => 'Hazır',
        FaloraReadingStatus.preparing => 'Hazırlanıyor',
        FaloraReadingStatus.pending => 'Beklemede',
      };

  Color get _bg => switch (status) {
        FaloraReadingStatus.ready => faloraSealReadyBg,
        FaloraReadingStatus.preparing => faloraSealPreparingBg,
        FaloraReadingStatus.pending => faloraSealPendingBg,
      };

  Color get _ink => switch (status) {
        FaloraReadingStatus.ready => faloraSealReadyInk,
        FaloraReadingStatus.preparing => faloraSealPreparingInk,
        FaloraReadingStatus.pending => faloraSealPendingInk,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _ink.withValues(alpha: 0.12)),
      ),
      child: Text(
        label ?? _defaultLabel,
        style: FaloraTypography.labelSmall.copyWith(
          color: _ink.withValues(alpha: 0.75),
          fontSize: 9,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Altın madalyon — uygulamanın en görünür jeton göstergesi.
class FaloraTokenMedallion extends StatelessWidget {
  const FaloraTokenMedallion({
    super.key,
    required this.tokens,
    this.compact = false,
    this.showLabel = false,
  });

  final int tokens;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 22.0 : 28.0;
    final fontSize = compact ? 19.0 : 28.0;
    final padH = compact ? 12.0 : 16.0;
    final padV = compact ? 7.0 : 10.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        shape: compact ? BoxShape.rectangle : BoxShape.rectangle,
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0E4C4), Color(0xFFE8D5A0), Color(0xFFD4AF37)],
          stops: [0.0, 0.45, 1.0],
        ),
        border: Border.all(color: faloraGoldDark, width: compact ? 1.6 : 2),
        boxShadow: [
          BoxShadow(
            color: faloraBronzeDark.withValues(alpha: 0.35),
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
          BoxShadow(
            color: faloraGold.withValues(alpha: 0.35),
            blurRadius: compact ? 6 : 10,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.coins,
            size: iconSize,
            color: faloraBronzeDark,
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            '$tokens',
            style: TextStyle(
              fontFamily: FaloraTypography.displayFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: faloraInk,
              height: 1,
              letterSpacing: -0.3,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              'jeton',
              style: FaloraTypography.labelSmall.copyWith(
                color: faloraBronzeDark,
                fontSize: compact ? 10 : 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sağ üst antik fiyat rozeti (jeton maliyeti).
class FaloraAncientPriceBadge extends StatelessWidget {
  const FaloraAncientPriceBadge({
    super.key,
    required this.amount,
    this.suffix,
  });

  final int amount;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: faloraParchmentInset.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: faloraGold.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(
            FontAwesomeIcons.coins,
            size: 12,
            color: faloraGoldDark,
          ),
          const SizedBox(width: 4),
          Text(
            suffix != null ? '$amount $suffix' : '$amount',
            style: FaloraTypography.labelLarge.copyWith(
              color: faloraInk,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Altın seçim sayacı — tarot X/Y.
class FaloraSelectionCounter extends StatelessWidget {
  const FaloraSelectionCounter({
    super.key,
    required this.selected,
    required this.total,
    this.prefix,
  });

  final int selected;
  final int total;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: faloraParchmentRaised,
        border: Border.all(color: faloraGold, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: faloraBronzeDark.withValues(alpha: 0.15),
            offset: const Offset(1, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        prefix ?? '$selected/$total',
        style: FaloraTypography.goldReadable.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Mühür tarzı ikincil buton — Kartları Seç vb.
class FaloraSealButton extends StatelessWidget {
  const FaloraSealButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(FaloraRadius.md),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FaloraRadius.md),
            color: enabled
                ? faloraParchmentRaised
                : faloraParchmentMid.withValues(alpha: 0.6),
            border: Border.all(
              color: enabled
                  ? faloraGold.withValues(alpha: 0.75)
                  : faloraBronze.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: faloraBronzeDark),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: FaloraTypography.labelLarge.copyWith(
                  color: enabled ? faloraBronzeDark : faloraInkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eski kayıt kartı — Fallarım listesi.
class FaloraRecordCard extends StatelessWidget {
  const FaloraRecordCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.status,
    this.statusLabel,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final FaloraReadingStatus status;
  final String? statusLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FaloraRadius.lg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: faloraParchmentDecoration(
            radius: FaloraRadius.lg,
            raised: true,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: FaloraTypography.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: FaloraTypography.labelSmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FaloraStatusSeal(status: status, label: statusLabel),
            ],
          ),
        ),
      ),
    );
  }
}

/// Antik kitap alt navigasyonu.
class FaloraAncientBottomNav extends StatelessWidget {
  const FaloraAncientBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.bottomPadding = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final double bottomPadding;

  static const _items = [
    (Icons.home_rounded, FontAwesomeIcons.house, 'Ana Sayfa'),
    (Icons.auto_stories_rounded, FontAwesomeIcons.bookOpen, 'Fallarım'),
    (Icons.favorite_rounded, FontAwesomeIcons.solidHeart, 'Çift Uyumu'),
    (Icons.person_rounded, FontAwesomeIcons.user, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: faloraParchmentCard,
        border: Border(
          top: BorderSide(color: faloraBronze.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
            color: faloraBronzeDark.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = i == currentIndex;
              final item = _items[i];
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: selected
                                ? faloraGold.withValues(alpha: 0.18)
                                : Colors.transparent,
                            border: selected
                                ? Border.all(
                                    color: faloraGold.withValues(alpha: 0.45),
                                  )
                                : null,
                          ),
                          child: FaIcon(
                            item.$2,
                            size: 18,
                            color: selected ? faloraGoldDark : faloraInkMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? faloraGoldDark : faloraInkMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Zodyak çemberi dekoru — Çift Uyumu hero.
class FaloraZodiacHero extends StatelessWidget {
  const FaloraZodiacHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onStart,
    this.accent = faloraBronze,
  });

  final String title;
  final String subtitle;
  final VoidCallback onStart;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return FaloraParchmentCard(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -20,
            right: -10,
            child: CustomPaint(
              size: const Size(120, 120),
              painter: _ZodiacRingPainter(color: faloraBronze.withValues(alpha: 0.12)),
            ),
          ),
          Column(
            children: [
              const FaIcon(
                FontAwesomeIcons.solidHeart,
                size: 32,
                color: faloraGoldDark,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: FaloraTypography.displayMedium,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: FaloraTypography.bodyLarge,
              ),
              const SizedBox(height: 22),
              FaloraPrimaryButton(
                label: 'Yeni Analiz Başlat',
                icon: Icons.auto_awesome,
                onPressed: onStart,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZodiacRingPainter extends CustomPainter {
  _ZodiacRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, size.width * 0.38, paint);
    canvas.drawCircle(center, size.width * 0.28, paint);

    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi - math.pi / 2;
      final x = center.dx + size.width * 0.38 * math.cos(angle);
      final y = center.dy + size.width * 0.38 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2.5, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bölüm başlığı — tüm ekranlarda tutarlı.
class FaloraSectionHeading extends StatelessWidget {
  const FaloraSectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: FaloraTypography.sectionHeading.copyWith(fontSize: 14),
    );
  }
}

/// Tarot masası arka plan dekorasyonu.
BoxDecoration faloraTarotTableDecoration() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [faloraTarotTableLight, faloraTarotFelt, faloraTarotTable],
    ),
    borderRadius: BorderRadius.vertical(top: Radius.circular(FaloraRadius.sheet)),
    border: Border(
      top: BorderSide(color: faloraGoldMuted, width: 1),
      left: BorderSide(color: faloraGoldMuted, width: 1),
      right: BorderSide(color: faloraGoldMuted, width: 1),
    ),
  );
}

BoxDecoration faloraTarotTableSurfaceDecoration() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [faloraTarotTableLight, faloraTarotFelt, faloraTarotTable],
    ),
  );
}

/// Büyük altın fiyat metni — mağaza.
class FaloraGoldPrice extends StatelessWidget {
  const FaloraGoldPrice({
    super.key,
    required this.price,
    this.large = false,
  });

  final String price;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Text(
      price,
      style: TextStyle(
        fontFamily: FaloraTypography.displayFamily,
        fontSize: large ? 28 : 24,
        fontWeight: FontWeight.w800,
        color: faloraGoldDark,
        height: 1.1,
        letterSpacing: -0.3,
      ),
    );
  }
}
