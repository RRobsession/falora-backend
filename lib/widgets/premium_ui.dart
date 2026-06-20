import 'dart:ui';

import 'package:falora/models/fortune_models.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Yumuşak sayfa geçişi.
Route<T> faloraPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, animation, __) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

BoxDecoration faloraGlassDecoration({
  Color accent = faloraAccent,
  double radius = 24,
  double opacity = 0.14,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.07),
        accent.withValues(alpha: opacity),
        const Color(0xFF120A22).withValues(alpha: 0.55),
      ],
    ),
    border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
    boxShadow: [
      BoxShadow(
        color: accent.withValues(alpha: 0.12),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

class FaloraBackground extends StatelessWidget {
  const FaloraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0612),
            Color(0xFF110D1F),
            Color(0xFF0D1528),
            Color(0xFF0A0612),
          ],
          stops: [0, 0.35, 0.7, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    faloraAccent.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    faloraGold.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class ScaleTap extends StatefulWidget {
  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class PremiumTokenBalanceCard extends StatefulWidget {
  const PremiumTokenBalanceCard({
    super.key,
    required this.tokens,
    this.compact = false,
  });

  final int tokens;
  final bool compact;

  @override
  State<PremiumTokenBalanceCard> createState() => _PremiumTokenBalanceCardState();
}

class _PremiumTokenBalanceCardState extends State<PremiumTokenBalanceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (context, child) {
        final glow = 0.35 + (_glowCtrl.value * 0.25);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 14 : 18,
            vertical: widget.compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                faloraGold.withValues(alpha: 0.22),
                const Color(0xFF2A1F45).withValues(alpha: 0.9),
                faloraAccent.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(
              color: faloraGold.withValues(alpha: 0.35 + (_glowCtrl.value * 0.15)),
            ),
            boxShadow: [
              BoxShadow(
                color: faloraGold.withValues(alpha: glow * 0.35),
                blurRadius: 20 + (_glowCtrl.value * 8),
                spreadRadius: _glowCtrl.value * 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.25),
              border: Border.all(color: faloraGold.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.toll_rounded, color: faloraGold, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.compact ? 'Bakiye' : 'Jeton Bakiyen',
                style: TextStyle(
                  color: faloraTextSecondary.withValues(alpha: 0.9),
                  fontSize: widget.compact ? 11 : 12,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                '${widget.tokens}',
                style: TextStyle(
                  color: faloraGold,
                  fontSize: widget.compact ? 22 : 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: faloraGold.withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PremiumWelcomeHeader extends StatelessWidget {
  const PremiumWelcomeHeader({
    super.key,
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 56, 22, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            decoration: faloraGlassDecoration(radius: 28, opacity: 0.18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.wandMagicSparkles,
                      color: faloraGold,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'FALORA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: faloraGold.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Merhaba, $userName',
                  style: const TextStyle(
                    color: faloraTextPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kozmik rehberin seni bekliyor',
                  style: TextStyle(
                    color: faloraTextSecondary.withValues(alpha: 0.92),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bugün hangi enerjiyi keşfetmek istiyorsun?',
                  style: TextStyle(
                    color: faloraTextPrimary.withValues(alpha: 0.88),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    super.key,
    required this.tokens,
    required this.onOpenShop,
    required this.onOpenReward,
  });

  final int tokens;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenReward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: faloraGold.withValues(alpha: 0.35)),
          ),
          child: Text(
            '🪙 $tokens',
            style: const TextStyle(
              color: faloraGold,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _QuickIconButton(
          icon: Icons.card_giftcard_rounded,
          tooltip: 'Ücretsiz jeton',
          onTap: onOpenReward,
          accent: faloraGold,
        ),
        const SizedBox(width: 6),
        _QuickIconButton(
          icon: Icons.storefront_rounded,
          tooltip: 'Jeton mağazası',
          onTap: onOpenShop,
          accent: faloraAccent,
        ),
      ],
    );
  }
}

class _QuickIconButton extends StatelessWidget {
  const _QuickIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.accent,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.28),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
      ),
    );
  }
}

class PremiumCategoryCard extends StatelessWidget {
  const PremiumCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  final FortuneCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              category.color.withValues(alpha: 0.20),
              category.color.withValues(alpha: 0.07),
            ],
          ),
          border: Border.all(
            color: category.color.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: category.color.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: category.color.withValues(alpha: 0.22),
                  border: Border.all(
                    color: category.color.withValues(alpha: 0.32),
                  ),
                ),
                child: Center(
                  child: FaIcon(
                    category.fallbackIcon,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.label,
                      style: const TextStyle(
                        color: faloraTextPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: faloraTextSecondary.withValues(alpha: 0.92),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: category.color.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GiftRewardCard extends StatelessWidget {
  const GiftRewardCard({
    super.key,
    required this.hasReward,
    required this.onWatch,
  });

  final bool hasReward;
  final VoidCallback? onWatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasReward
              ? [
                  const Color(0xFF3D2A5C),
                  const Color(0xFF251838),
                  faloraGold.withValues(alpha: 0.15),
                ]
              : [
                  const Color(0xFF1E1630),
                  const Color(0xFF151020),
                ],
        ),
        border: Border.all(
          color: hasReward
              ? faloraGold.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: hasReward
            ? [
                BoxShadow(
                  color: faloraGold.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      faloraGold.withValues(alpha: 0.35),
                      faloraAccent.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.gift,
                  color: faloraGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [faloraGold, Color(0xFFFFE8A3)],
                      ).createShader(bounds),
                      child: const Text(
                        'Ücretsiz 50 Jeton Kazan',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasReward
                          ? 'Bugünkü ücretsiz jeton hakkın hazır.'
                          : 'Bugünkü ücretsiz jeton hakkını kullandın.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: faloraTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ScaleTap(
            enabled: hasReward,
            onTap: onWatch,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: hasReward
                    ? const LinearGradient(
                        colors: [faloraGold, Color(0xFFB8942E)],
                      )
                    : null,
                color: hasReward ? null : Colors.white.withValues(alpha: 0.05),
                border: hasReward
                    ? null
                    : Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              alignment: Alignment.center,
              child: Text(
                hasReward
                    ? 'Reklam İzle ve 50 Jeton Kazan'
                    : 'Bugünkü hak kullanıldı',
                style: TextStyle(
                  color: hasReward ? const Color(0xFF1A1028) : faloraTextSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ortalanmış kompakt ücretsiz jeton popup'ı.
class GiftRewardModal extends StatelessWidget {
  const GiftRewardModal({
    super.key,
    required this.hasReward,
    required this.onClose,
    this.onWatch,
  });

  final bool hasReward;
  final VoidCallback onClose;
  final VoidCallback? onWatch;

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.sizeOf(context).width * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: cardWidth,
        maxHeight: 280,
      ),
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasReward
                ? [
                    const Color(0xFF3D2A5C),
                    const Color(0xFF251838),
                    faloraGold.withValues(alpha: 0.12),
                  ]
                : [
                    const Color(0xFF1E1630),
                    const Color(0xFF151020),
                  ],
          ),
          border: Border.all(
            color: hasReward
                ? faloraGold.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            if (hasReward)
              BoxShadow(
                color: faloraGold.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [faloraGold, Color(0xFFFFE8A3)],
              ).createShader(bounds),
              child: const Text(
                '🎁 Ücretsiz 50 Jeton Kazan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
            ),
            if (!hasReward) ...[
              const SizedBox(height: 10),
              const Text(
                'Bugünkü ücretsiz jeton hakkını kullandın.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: faloraTextSecondary,
                  height: 1.35,
                ),
              ),
            ],
            SizedBox(height: hasReward ? 18 : 14),
            ScaleTap(
              onTap: hasReward ? onWatch : onClose,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: hasReward
                      ? const LinearGradient(
                          colors: [faloraGold, Color(0xFFB8942E)],
                        )
                      : null,
                  color: hasReward ? null : Colors.white.withValues(alpha: 0.06),
                  border: hasReward
                      ? null
                      : Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                alignment: Alignment.center,
                child: Text(
                  hasReward
                      ? '📺 Reklam İzle ve 50 Jeton Kazan'
                      : 'Tamam',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: hasReward
                        ? const Color(0xFF1A1028)
                        : faloraTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShopPackageCard extends StatelessWidget {
  const ShopPackageCard({
    super.key,
    required this.tokens,
    required this.priceTry,
    required this.badge,
    required this.highlight,
    required this.onBuy,
  });

  final int tokens;
  final int priceTry;
  final String? badge;
  final bool highlight;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onBuy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: highlight
                ? [
                    faloraGold.withValues(alpha: 0.16),
                    const Color(0xFF221836),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.05),
                    const Color(0xFF181228),
                  ],
          ),
          border: Border.all(
            color: highlight
                ? faloraGold.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: highlight
              ? [
                  BoxShadow(
                    color: faloraGold.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    Text(
                      badge!,
                      style: TextStyle(
                        color: highlight ? faloraGold : faloraAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$tokens',
                        style: TextStyle(
                          fontSize: highlight ? 28 : 24,
                          fontWeight: FontWeight.w800,
                          color: highlight ? faloraGold : faloraTextPrimary,
                          height: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 6, bottom: 3),
                        child: Text(
                          'Jeton',
                          style: TextStyle(
                            color: faloraTextSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$priceTry TL',
                    style: TextStyle(
                      color: faloraTextSecondary.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: highlight
                    ? const LinearGradient(
                        colors: [faloraGold, Color(0xFFB8942E)],
                      )
                    : LinearGradient(
                        colors: [
                          faloraAccent.withValues(alpha: 0.85),
                          faloraAccent.withValues(alpha: 0.6),
                        ],
                      ),
              ),
              child: Text(
                'Satın Al',
                style: TextStyle(
                  color: highlight ? const Color(0xFF1A1028) : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompatibilityRing extends StatelessWidget {
  const CompatibilityRing({super.key, required this.percent, this.size = 168});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent >= 70
                    ? const Color(0xFFE879A8)
                    : percent >= 50
                        ? faloraGold
                        : faloraAccent,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '%$percent',
                style: TextStyle(
                  fontSize: size * 0.24,
                  fontWeight: FontWeight.w800,
                  color: faloraTextPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Uyumluluk',
                style: TextStyle(
                  fontSize: 13,
                  color: faloraTextSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CoupleSubScores {
  const CoupleSubScores({
    required this.emotional,
    required this.communication,
    required this.passion,
    required this.trust,
  });

  final int emotional;
  final int communication;
  final int passion;
  final int trust;
}

CoupleSubScores deriveCoupleSubScores(int overall, String seed) {
  var hash = seed.hashCode;
  int nextOffset() {
    hash = (hash * 1103515245 + 12345) & 0x7fffffff;
    return (hash % 17) - 8;
  }

  int clampScore(int value) => value.clamp(35, 98);

  return CoupleSubScores(
    emotional: clampScore(overall + nextOffset()),
    communication: clampScore(overall + nextOffset()),
    passion: clampScore(overall + nextOffset() - 2),
    trust: clampScore(overall + nextOffset() + 1),
  );
}

class CoupleCompatibilityDashboard extends StatelessWidget {
  const CoupleCompatibilityDashboard({
    super.key,
    required this.percent,
    required this.readingId,
  });

  final int percent;
  final String readingId;

  @override
  Widget build(BuildContext context) {
    final scores = deriveCoupleSubScores(percent, readingId);
    final items = [
      ('Duygusal Uyum', scores.emotional, Icons.favorite_rounded),
      ('İletişim', scores.communication, Icons.chat_bubble_rounded),
      ('Tutku', scores.passion, Icons.local_fire_department_rounded),
      ('Güven', scores.trust, Icons.verified_user_rounded),
    ];

    return Column(
      children: [
        CompatibilityRing(percent: percent),
        const SizedBox(height: 22),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.35,
          children: items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(item.$3, size: 14, color: faloraAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: faloraTextSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        '${item.$2}%',
                        style: const TextStyle(
                          color: faloraGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.$2 / 100,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        faloraAccent.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

int? parseCompatibilityPercent(String text) {
  final match = RegExp(r'Uyumluluk:\s*%(\d+)').firstMatch(text);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

String stripCompatibilityHeader(String text) {
  return text.replaceFirst(RegExp(r'^Uyumluluk:\s*%?\d+\s*\n*'), '').trim();
}

List<String> splitFortuneParagraphs(String text) {
  final normalized = text.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) return const [];
  final parts = normalized.split(RegExp(r'\n\s*\n'));
  if (parts.length > 1) return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  return [normalized];
}

class PremiumOutlinedButton extends StatelessWidget {
  const PremiumOutlinedButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: faloraGold.withValues(alpha: 0.55)),
          gradient: LinearGradient(
            colors: [
              faloraGold.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: faloraGold, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: faloraGold,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
