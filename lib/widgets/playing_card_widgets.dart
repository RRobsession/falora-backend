import 'dart:math';

import 'package:falora/models/playing_card.dart';
import 'package:falora/services/playing_card_deck_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum PlayingCardDisplayMode { faceDown, faceUp }

class PlayingCardFace extends StatelessWidget {
  const PlayingCardFace({
    super.key,
    required this.mode,
    this.selection,
    this.showPositionBadge = false,
    this.selectedGlow = false,
  });

  final PlayingCardDisplayMode mode;
  final PlayingCardSelection? selection;
  final bool showPositionBadge;
  final bool selectedGlow;

  @override
  Widget build(BuildContext context) {
    if (mode == PlayingCardDisplayMode.faceDown || selection == null) {
      return _PlayingCardBack(selectedGlow: selectedGlow);
    }

    final imagePath = selection!.assetPath.isNotEmpty
        ? selection!.assetPath
        : playingAssetPathForId(selection!.id);
    final borderColor = selectedGlow
        ? faloraGold.withValues(alpha: 0.75)
        : faloraGold.withValues(alpha: 0.28);

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: selectedGlow ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: faloraBronzeDark.withValues(alpha: selectedGlow ? 0.2 : 0.12),
            offset: const Offset(1, 2),
            blurRadius: selectedGlow ? 4 : 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.rotate(
            angle: selection!.isReversed ? pi : 0,
            child: ColoredBox(
              color: const Color(0xFFFFFDF8),
              child: SvgPicture.asset(
                imagePath,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                placeholderBuilder: (_) => const _ImageFallback(),
              ),
            ),
          ),
          if (selection!.isReversed)
            const Positioned(top: 3, left: 3, child: _ReversedBadge()),
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

class _PlayingCardBack extends StatelessWidget {
  const _PlayingCardBack({required this.selectedGlow});

  final bool selectedGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B1A1A),
            Color(0xFF5C1010),
            Color(0xFF3A0808),
          ],
        ),
        border: Border.all(
          color: selectedGlow
              ? faloraGold
              : faloraGold.withValues(alpha: 0.45),
          width: selectedGlow ? 1.5 : 1,
        ),
      ),
      child: CustomPaint(
        painter: _PlayingCardBackPainter(),
      ),
    );
  }
}

class _PlayingCardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
        const Radius.circular(4),
      ),
      border,
    );

    final diamond = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFFE8B8).withValues(alpha: 0.22);

    final cx = size.width / 2;
    final cy = size.height / 2;
    for (var i = -2; i <= 2; i++) {
      for (var j = -3; j <= 3; j++) {
        final path = Path()
          ..moveTo(cx + i * 14, cy + j * 10 - 5)
          ..lineTo(cx + i * 14 + 5, cy + j * 10)
          ..lineTo(cx + i * 14, cy + j * 10 + 5)
          ..lineTo(cx + i * 14 - 5, cy + j * 10)
          ..close();
        canvas.drawPath(path, diamond);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReversedBadge extends StatelessWidget {
  const _ReversedBadge();

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
      color: const Color(0xFFFFFDF8),
      alignment: Alignment.center,
      child: FaIcon(
        FontAwesomeIcons.image,
        size: 20,
        color: faloraGold.withValues(alpha: 0.45),
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
        border: Border.all(color: const Color(0xFF2E2115)),
      ),
      child: Text(
        '$index',
        style: const TextStyle(
          color: faloraInk,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class PlayingCardTile extends StatelessWidget {
  const PlayingCardTile({
    super.key,
    required this.faceUp,
    this.selection,
    this.selectedGlow = false,
    this.showPositionBadge = false,
    this.onTap,
  });

  final bool faceUp;
  final PlayingCardSelection? selection;
  final bool selectedGlow;
  final bool showPositionBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = PlayingCardDeckService.instance.cardAspectRatio;
    return AspectRatio(
      aspectRatio: ratio,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: PlayingCardFace(
            mode: faceUp
                ? PlayingCardDisplayMode.faceUp
                : PlayingCardDisplayMode.faceDown,
            selection: selection,
            selectedGlow: selectedGlow,
            showPositionBadge: showPositionBadge,
          ),
        ),
      ),
    );
  }
}

class PlayingPickerGridCard extends StatelessWidget {
  const PlayingPickerGridCard({
    super.key,
    required this.selection,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
  });

  final PlayingCardSelection? selection;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: !isSelected && !canSelect ? 0.45 : 1,
      child: PlayingCardTile(
        faceUp: isSelected,
        selection: selection,
        selectedGlow: isSelected,
        showPositionBadge: isSelected,
        onTap: canSelect || isSelected ? onTap : null,
      ),
    );
  }
}

class PlayingSpreadCardItem extends StatelessWidget {
  const PlayingSpreadCardItem({
    super.key,
    required this.selection,
    this.compact = false,
  });

  final PlayingCardSelection selection;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ratio = PlayingCardDeckService.instance.cardAspectRatio;
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
              child: PlayingCardFace(
                mode: PlayingCardDisplayMode.faceUp,
                selection: selection,
                showPositionBadge: true,
                selectedGlow: true,
              ),
            ),
            SizedBox(height: compact ? 3 : 4),
            Text(
              selection.nameTr,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: faloraTextPrimary,
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              selection.positionLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: faloraGold.withValues(alpha: 0.85),
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlayingSelectedCardsStrip extends StatelessWidget {
  const PlayingSelectedCardsStrip({super.key, required this.cards});

  final List<PlayingCardSelection> cards;

  @override
  Widget build(BuildContext context) {
    final sorted = [...cards]
      ..sort((a, b) => a.positionIndex.compareTo(b.positionIndex));
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 62,
            child: PlayingSpreadCardItem(
              selection: sorted[index],
              compact: true,
            ),
          );
        },
      ),
    );
  }
}

class PlayingResultCardsGrid extends StatelessWidget {
  const PlayingResultCardsGrid({super.key, required this.cards});

  final List<PlayingCardSelection> cards;

  @override
  Widget build(BuildContext context) {
    final sorted = [...cards]
      ..sort((a, b) => a.positionIndex.compareTo(b.positionIndex));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return PlayingSpreadCardItem(selection: sorted[index]);
      },
    );
  }
}
