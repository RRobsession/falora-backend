import 'dart:math';

import 'package:falora/config/tarot_card_visuals.dart';
import 'package:falora/models/tarot_card.dart';
import 'package:falora/services/tarot_deck_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum TarotCardDisplayMode {
  faceDown,
  faceUp,
}

/// Premium tarot kart yüzü (gerçek JPG veya kapalı yüz).
class TarotCardFace extends StatelessWidget {
  const TarotCardFace({
    super.key,
    required this.mode,
    this.selection,
    this.showPositionBadge = false,
    this.selectedGlow = false,
  });

  final TarotCardDisplayMode mode;
  final TarotCardSelection? selection;
  final bool showPositionBadge;
  final bool selectedGlow;

  @override
  Widget build(BuildContext context) {
    if (mode == TarotCardDisplayMode.faceDown || selection == null) {
      return _FaceDownSurface(selectedGlow: selectedGlow);
    }

    final imagePath = tarotImageAssetPath(selection!);
    final borderColor = selectedGlow
        ? faloraGold.withValues(alpha: 0.75)
        : faloraGold.withValues(alpha: 0.28);

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: selectedGlow ? 1.5 : 1,
        ),
        boxShadow: selectedGlow
            ? [
                BoxShadow(
                  color: faloraGold.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : [
                BoxShadow(
                  color: faloraBronzeDark.withValues(alpha: 0.15),
                  offset: const Offset(1, 2),
                  blurRadius: 0,
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.rotate(
            angle: selection!.isReversed ? pi : 0,
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const _ImageFallback(),
            ),
          ),
          if (selection!.isReversed)
            Positioned(
              top: 3,
              left: 3,
              child: _ReversedBadge(),
            ),
          if (showPositionBadge)
            Positioned(
              top: 3,
              right: 3,
              child: _PositionBadge(index: selection!.positionIndex),
            ),
        ],
      ),
    );
  }
}

class _ReversedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Ters',
        style: TextStyle(
          color: faloraGold.withValues(alpha: 0.9),
          fontSize: 7,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: faloraParchmentInset,
      alignment: Alignment.center,
      child: FaIcon(
        FontAwesomeIcons.image,
        size: 20,
        color: faloraGold.withValues(alpha: 0.45),
      ),
    );
  }
}

class _FaceDownSurface extends StatelessWidget {
  const _FaceDownSurface({required this.selectedGlow});

  final bool selectedGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            faloraParchmentRaised,
            faloraParchmentInset,
            faloraParchmentDeep,
          ],
        ),
        border: Border.all(
          color: selectedGlow
              ? faloraGoldDark
              : faloraGold.withValues(alpha: 0.45),
          width: selectedGlow ? 1.5 : 1,
        ),
        boxShadow: selectedGlow
            ? [
                BoxShadow(
                  color: faloraGold.withValues(alpha: 0.2),
                  offset: const Offset(0, 1),
                  blurRadius: 4,
                ),
              ]
            : [
                BoxShadow(
                  color: faloraBronzeDark.withValues(alpha: 0.2),
                  offset: const Offset(1, 2),
                  blurRadius: 0,
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.star,
          size: 14,
          color: faloraGoldDark.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: faloraGold,
        border: Border.all(
          color: const Color(0xFF2E2115),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '$index',
        style: TextStyle(
          color: faloraInk,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

/// Kart + alt etiket (form / sonuç grid).
class TarotSpreadCardItem extends StatelessWidget {
  const TarotSpreadCardItem({
    super.key,
    required this.selection,
    this.showPositionBadge = true,
    this.labelStyle,
    this.compact = false,
  });

  final TarotCardSelection selection;
  final bool showPositionBadge;
  final TextStyle? labelStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ratio = TarotDeckService.instance.cardAspectRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = cardWidth / ratio;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: TarotCardFace(
                mode: TarotCardDisplayMode.faceUp,
                selection: selection,
                showPositionBadge: showPositionBadge,
                selectedGlow: true,
              ),
            ),
            SizedBox(height: compact ? 3 : 4),
            Text(
              selection.id.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle ??
                  TextStyle(
                    color: faloraTextPrimary,
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    letterSpacing: 0.2,
                  ),
            ),
            if (selection.isReversed && !compact)
              Text(
                'Ters',
                style: TextStyle(
                  color: faloraGold.withValues(alpha: 0.85),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Kapalı veya açık tarot kartı (picker grid).
class TarotCardTile extends StatelessWidget {
  const TarotCardTile({
    super.key,
    required this.faceUp,
    this.selection,
    this.selectedGlow = false,
    this.showPositionBadge = false,
    this.onTap,
    this.locked = false,
  });

  final bool faceUp;
  final TarotCardSelection? selection;
  final bool selectedGlow;
  final bool showPositionBadge;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final ratio = TarotDeckService.instance.cardAspectRatio;

    return GestureDetector(
      onTap: locked ? null : onTap,
      child: AspectRatio(
        aspectRatio: ratio,
        child: TarotCardFace(
          mode: faceUp && selection != null
              ? TarotCardDisplayMode.faceUp
              : TarotCardDisplayMode.faceDown,
          selection: selection,
          showPositionBadge: showPositionBadge && faceUp,
          selectedGlow: selectedGlow,
        ),
      ),
    );
  }
}

/// Flip animasyonlu grid kartı.
class TarotPickerGridCard extends StatefulWidget {
  const TarotPickerGridCard({
    super.key,
    required this.selection,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
  });

  final TarotCardSelection? selection;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;

  @override
  State<TarotPickerGridCard> createState() => _TarotPickerGridCardState();
}

class _TarotPickerGridCardState extends State<TarotPickerGridCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _flipAnim = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );
    if (widget.isSelected) _flipCtrl.value = 1;
  }

  @override
  void didUpdateWidget(TarotPickerGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _flipCtrl.forward();
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipAnim,
      builder: (context, child) {
        final angle = _flipAnim.value;
        final showFront = angle >= pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: showFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: TarotCardTile(
                    faceUp: true,
                    selection: widget.selection,
                    selectedGlow: widget.isSelected,
                    showPositionBadge: true,
                    locked: widget.isSelected,
                    onTap: null,
                  ),
                )
              : TarotCardTile(
                  faceUp: false,
                  selectedGlow: false,
                  onTap: widget.canSelect ? widget.onTap : null,
                ),
        );
      },
    );
  }
}

/// Form ekranında seçilen kartlar — yatay kaydırma.
class TarotSelectedCardsStrip extends StatelessWidget {
  const TarotSelectedCardsStrip({super.key, required this.cards});

  final List<TarotCardSelection> cards;

  static const _cardWidth = 68.0;
  static const _labelBlockHeight = 30.0;

  @override
  Widget build(BuildContext context) {
    final ratio = TarotDeckService.instance.cardAspectRatio;
    final cardHeight = _cardWidth / ratio;
    final stripHeight = cardHeight + 4 + _labelBlockHeight;

    return SizedBox(
      height: stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          return SizedBox(
            width: _cardWidth,
            child: TarotSpreadCardItem(
              selection: cards[index],
              showPositionBadge: true,
            ),
          );
        },
      ),
    );
  }
}

/// Sonuç ekranı — kompakt responsive grid.
class TarotResultCardsGrid extends StatelessWidget {
  const TarotResultCardsGrid({super.key, required this.cards});

  final List<TarotCardSelection> cards;

  static const _horizontalPadding = 20.0;
  static const _gridSpacing = 5.0;
  static const _labelBlockHeight = 22.0;

  /// 8 kart → 4 sütun × 2 satır (kompakt mobil grid).
  static const _resultGridColumns = 4;

  double _childAspectRatio(double width, int columns) {
    final ratio = TarotDeckService.instance.cardAspectRatio;
    final spacing = _gridSpacing * (columns - 1);
    final cellWidth = (width - _horizontalPadding - spacing) / columns;
    final cardHeight = cellWidth / ratio;
    final cellHeight = cardHeight + 3 + _labelBlockHeight;
    return cellWidth / cellHeight;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    const columns = _resultGridColumns;
    final aspectRatio = _childAspectRatio(width, columns);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: _gridSpacing,
        mainAxisSpacing: _gridSpacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return TarotSpreadCardItem(
          selection: cards[index],
          showPositionBadge: true,
          compact: true,
        );
      },
    );
  }
}
