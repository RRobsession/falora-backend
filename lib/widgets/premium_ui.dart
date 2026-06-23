import 'package:falora/config/app_branding.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/token_config.dart';
import 'package:falora/widgets/falora_component_library.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

export 'falora_component_library.dart';

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

class FaloraBackground extends StatelessWidget {
  const FaloraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FaloraParchmentBackground(child: child);
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
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 14 : 18,
            vertical: widget.compact ? 10 : 14,
          ),
          decoration: faloraParchmentDecoration(
            base: Color.lerp(
              faloraParchmentCard,
              faloraGold,
              0.08 + (_glowCtrl.value * 0.04),
            )!,
            radius: 20,
            raised: true,
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
              color: faloraParchmentInset.withValues(alpha: 0.8),
              border: Border.all(color: faloraGold.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.toll_rounded, color: faloraGoldReadable, size: 22),
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
                  color: faloraInk,
                  fontSize: widget.compact ? 22 : 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        decoration: faloraParchmentDecoration(radius: FaloraRadius.xl),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.wandMagicSparkles,
                      color: faloraGoldReadable,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      appDisplayName.toUpperCase(),
                      style: FaloraTypography.labelLarge.copyWith(
                        fontSize: 13,
                        letterSpacing: 4,
                        color: faloraInkHeading,
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
                  'Kadim yorumcunun sayfaları açıldı',
                  style: FaloraTypography.bodyLarge,
                ),
                const SizedBox(height: 14),
                Text(
                  'Bugün hangi falı keşfetmek istiyorsun?',
                  style: FaloraTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
        FaloraTappableTokenBalance(
          tokens: tokens,
          onTap: onOpenShop,
          compact: true,
          showHint: false,
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
            color: faloraParchmentInset.withValues(alpha: 0.75),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
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
        decoration: faloraParchmentDecoration(
          base: Color.lerp(faloraParchmentCard, category.color, 0.1)!,
          radius: FaloraRadius.xl,
          raised: true,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FaloraRadius.lg),
                  color: faloraParchmentInset.withValues(alpha: 0.65),
                  border: Border.all(
                    color: category.color.withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: FaIcon(
                    category.fallbackIcon,
                    color: faloraBronzeDark,
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
                      style: FaloraTypography.titleLarge.copyWith(
                        color: faloraInk,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category == FortuneCategory.ciftUyumu
                          ? '${category.description} · $coupleTokenCost jeton'
                          : category.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FaloraTypography.bodyMedium.copyWith(
                        color: faloraInkSoft,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: faloraBronzeDark.withValues(alpha: 0.55),
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
    required this.rewardAdsUsed,
    required this.onWatch,
  });

  final bool hasReward;
  final int rewardAdsUsed;
  final VoidCallback? onWatch;

  String get _quotaLabel =>
      'Bugünkü reklam hakkı: $rewardAdsUsed/$maxRewardedAdsPerDay';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
        decoration: faloraParchmentDecoration(
          base: hasReward
              ? Color.lerp(faloraParchmentCard, faloraGold, 0.12)!
              : faloraParchmentInset,
          radius: FaloraRadius.xl,
          raised: hasReward,
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
                  color: faloraGoldReadable,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ücretsiz 50 Jeton Kazan',
                      style: FaloraTypography.titleLarge.copyWith(
                        color: faloraInkHeading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _quotaLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: faloraBronzeDark,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasReward
                          ? 'Her reklam +$rewardAdTokenGrant jeton kazandırır.'
                          : rewardAdLimitReachedMessage,
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
                borderRadius: BorderRadius.circular(FaloraRadius.md),
                color: hasReward ? faloraBronzeDark : faloraParchmentMid,
                border: Border.all(
                  color: hasReward
                      ? faloraGold
                      : faloraBronze.withValues(alpha: 0.25),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                hasReward
                    ? 'Reklam İzle ve 50 Jeton Kazan'
                    : 'Bugünkü hak doldu',
                style: TextStyle(
                  color: hasReward ? faloraParchmentRaised : faloraTextSecondary,
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
    required this.rewardAdsUsed,
    required this.onClose,
    this.onWatch,
  });

  final bool hasReward;
  final int rewardAdsUsed;
  final VoidCallback onClose;
  final VoidCallback? onWatch;

  String get _quotaLabel =>
      'Bugünkü reklam hakkı: $rewardAdsUsed/$maxRewardedAdsPerDay';

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
        decoration: faloraParchmentDecoration(
          base: hasReward
              ? Color.lerp(faloraParchmentCard, faloraGold, 0.1)!
              : faloraParchmentInset,
          radius: FaloraRadius.xl,
          raised: true,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '🎁 Ücretsiz 50 Jeton Kazan',
              textAlign: TextAlign.center,
              style: FaloraTypography.titleLarge.copyWith(color: faloraInkHeading),
            ),
            const SizedBox(height: 8),
            Text(
              _quotaLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: faloraBronzeDark,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (!hasReward) ...[
              const SizedBox(height: 8),
              const Text(
                rewardAdLimitReachedMessage,
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
                  color: hasReward ? faloraBronzeDark : faloraParchmentMid,
                  border: Border.all(
                    color: hasReward
                        ? faloraGold
                        : faloraBronze.withValues(alpha: 0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  hasReward
                      ? '📺 Reklam İzle ve 50 Jeton Kazan'
                      : 'Tamam',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: hasReward
                        ? faloraParchmentRaised
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

/// Mağaza ürünleri yüklenirken tam liste iskeleti.
class ShopProductsSkeleton extends StatefulWidget {
  const ShopProductsSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  State<ShopProductsSkeleton> createState() => _ShopProductsSkeletonState();
}

class _ShopProductsSkeletonState extends State<ShopProductsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: widget.itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _ShopPackageSkeletonCard(
          animation: _controller,
          highlight: index == 1,
        );
      },
    );
  }
}

class _ShopPackageSkeletonCard extends StatelessWidget {
  const _ShopPackageSkeletonCard({
    required this.animation,
    required this.highlight,
  });

  final Animation<double> animation;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: faloraParchmentDecoration(
        base: highlight
            ? Color.lerp(faloraParchmentCard, faloraGold, 0.08)!
            : faloraParchmentInset,
        radius: FaloraRadius.xl,
        raised: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (highlight) ...[
            _ShimmerBar(animation: animation, width: 88, height: 22),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBar(
                      animation: animation,
                      width: 120,
                      height: highlight ? 36 : 32,
                    ),
                    const SizedBox(height: 10),
                    _ShimmerBar(animation: animation, width: 140, height: 14),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ShimmerBar(animation: animation, width: 72, height: 28),
            ],
          ),
          const SizedBox(height: 18),
          _ShimmerBar(animation: animation, width: double.infinity, height: 48),
        ],
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({
    required this.animation,
    required this.width,
    required this.height,
  });

  final Animation<double> animation;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height > 20 ? 12 : 8),
            gradient: LinearGradient(
              begin: Alignment(-1 + animation.value * 2, 0),
              end: Alignment(animation.value * 2, 0),
              colors: [
                Colors.white.withValues(alpha: 0.04),
                faloraGold.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ShopPackageCard extends StatelessWidget {
  const ShopPackageCard({
    super.key,
    required this.tokens,
    required this.subtitle,
    required this.badge,
    required this.highlight,
    required this.price,
    this.isPurchasing = false,
    required this.onBuy,
  });

  final int tokens;
  final String subtitle;
  final String? badge;
  final bool highlight;
  final String price;
  final bool isPurchasing;
  final VoidCallback? onBuy;

  bool get _canBuy => onBuy != null && !isPurchasing;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: faloraParchmentDecoration(
          base: highlight
              ? Color.lerp(faloraParchmentCard, faloraGold, 0.16)!
              : faloraParchmentCard,
          radius: FaloraRadius.xl,
          raised: true,
          borderWidth: highlight ? 1.5 : 1.2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (badge != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: highlight
                        ? faloraGold.withValues(alpha: 0.2)
                        : faloraAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: highlight
                          ? faloraGold.withValues(alpha: 0.45)
                          : faloraAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: highlight ? faloraGoldReadable : faloraBronzeDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$tokens',
                            style: TextStyle(
                              fontSize: highlight ? 36 : 32,
                              fontWeight: FontWeight.w800,
                              color: highlight ? faloraGoldReadable : faloraInk,
                              height: 1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 8, bottom: 4),
                            child: Text(
                              'Jeton',
                              style: TextStyle(
                                color: faloraTextSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: highlight
                              ? faloraInkHeading
                              : faloraInkSoft.withValues(alpha: 0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FaloraGoldPrice(price: price, large: highlight),
              ],
            ),
            const SizedBox(height: 18),
            _BuyButton(
              highlight: highlight,
              enabled: _canBuy,
              isPurchasing: isPurchasing,
              onPressed: _canBuy ? onBuy : null,
            ),
          ],
        ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.highlight,
    required this.enabled,
    required this.isPurchasing,
    required this.onPressed,
  });

  final bool highlight;
  final bool enabled;
  final bool isPurchasing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FaloraRadius.md),
            color: enabled
                ? (highlight ? faloraBronzeDark : faloraBronze)
                : faloraParchmentMid,
            border: Border.all(
              color: enabled
                  ? faloraGold
                  : faloraBronze.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: isPurchasing
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: faloraParchmentRaised,
                    ),
                  )
                : Text(
                    'Satın Al',
                    style: TextStyle(
                      color: enabled
                          ? faloraParchmentRaised
                          : faloraTextSecondary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
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
              backgroundColor: faloraProgressTrack,
              valueColor: const AlwaysStoppedAnimation<Color>(faloraProgressFill),
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
                  color: faloraInk,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Uyumluluk',
                style: FaloraTypography.bodyMedium.copyWith(
                  fontSize: 13,
                  color: faloraInkHeading,
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
              decoration: faloraParchmentDecoration(
                radius: FaloraRadius.md,
                raised: false,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(item.$3, size: 14, color: faloraBronzeDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FaloraTypography.labelSmall.copyWith(
                            color: faloraInkHeading,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        '${item.$2}%',
                        style: FaloraTypography.labelLarge.copyWith(
                          color: faloraInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
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
                      backgroundColor: faloraProgressTrack,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        faloraProgressFill,
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
          borderRadius: BorderRadius.circular(FaloraRadius.md),
          color: faloraParchmentInset.withValues(alpha: 0.85),
          border: Border.all(color: faloraGoldDark, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: faloraBronzeDark.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: faloraInkHeading, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: FaloraTypography.labelLarge.copyWith(
                color: faloraInkHeading,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
