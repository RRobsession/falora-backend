import 'package:falora/config/manual_fortune_config.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/models/fortune_teller_models.dart';
import 'package:falora/models/manual_fortune_reader.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/live_token_builder.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:falora/widgets/fortune_teller_avatar.dart';
import 'package:falora/widgets/manual_fortune_reader_avatar.dart';
import 'package:flutter/material.dart';

/// Fal türü seçildikten sonra falcı seçim ekranı.
class FortuneTellerSelectionPage extends StatefulWidget {
  const FortuneTellerSelectionPage({
    super.key,
    required this.category,
    required this.onTellerChosen,
    required this.onManualReaderChosen,
  });

  final FortuneCategory category;
  final void Function(BuildContext context, FortuneTeller teller) onTellerChosen;
  final void Function(BuildContext context, ManualFortuneReader reader)
      onManualReaderChosen;

  @override
  State<FortuneTellerSelectionPage> createState() =>
      _FortuneTellerSelectionPageState();
}

class _FortuneTellerSelectionPageState extends State<FortuneTellerSelectionPage> {
  late final ManualFortuneOffer _manualOffer;

  @override
  void initState() {
    super.initState();
    _manualOffer = manualOfferFor(widget.category);
    logManualReaderConfig(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return Scaffold(
      appBar: AppBar(
        title: Text(category.label),
      ),
      body: FaloraBackground(
        child: LiveTokenBuilder(
          builder: (context, tokens) {
            return ListView(
              padding: EdgeInsets.fromLTRB(
                22,
                12,
                22,
                28 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: faloraGlassDecoration(
                      accent: category.color,
                      radius: 22,
                      opacity: 0.18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Falcını Seç',
                          style: TextStyle(
                            color: faloraGold.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI falcılar jeton ile anında yorum üretir. '
                          'Serdar ve Hatice birebir özel yorum sunar; '
                          '${_manualOffer.questionLimit} soru · ${_manualOffer.priceLabel}.',
                          style: const TextStyle(
                            color: faloraTextSecondary,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.toll, color: faloraGold, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'AI bakiyen: $tokens jeton',
                              style: const TextStyle(
                                color: faloraGold,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'AI Falcılar',
                  style: TextStyle(
                    color: category.color.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                ...fortuneTellers.map(
                  (teller) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FortuneTellerCard(
                      teller: teller,
                      userTokens: tokens,
                      onTap: () => widget.onTellerChosen(context, teller),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Özel Yorumcular',
                  style: TextStyle(
                    color: faloraGold.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                ...manualFortuneReaders.map(
                  (reader) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ManualFortuneReaderCard(
                      reader: reader,
                      category: category,
                      offer: _manualOffer,
                      onTap: () => widget.onManualReaderChosen(context, reader),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ManualFortuneReaderCard extends StatelessWidget {
  const _ManualFortuneReaderCard({
    required this.reader,
    required this.category,
    required this.offer,
    required this.onTap,
  });

  final ManualFortuneReader reader;
  final FortuneCategory category;
  final ManualFortuneOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              reader.accentColor.withValues(alpha: 0.22),
              const Color(0xFF1A1228),
              faloraGold.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(
            color: faloraGold.withValues(alpha: 0.32),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: reader.accentColor.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ManualFortuneReaderAvatar(reader: reader),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: faloraGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: faloraGold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          manualReaderBadgeLabel,
                          style: const TextStyle(
                            color: faloraGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reader.name,
                        style: const TextStyle(
                          color: faloraTextPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reader.title,
                        style: TextStyle(
                          color: reader.accentColor.withValues(alpha: 0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: faloraGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    offer.priceLabel,
                    style: const TextStyle(
                      color: faloraGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              reader.bio,
              style: const TextStyle(
                color: faloraTextSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  label: offer.questionLabel,
                  color: reader.accentColor,
                ),
                _InfoChip(
                  label: offer.intentionLabel,
                  color: faloraGold,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    reader.accentColor,
                    reader.accentColor.withValues(alpha: 0.75),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Satın Al · ${offer.priceLabel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FortuneTellerCard extends StatelessWidget {
  const _FortuneTellerCard({
    required this.teller,
    required this.userTokens,
    required this.onTap,
  });

  final FortuneTeller teller;
  final int userTokens;
  final VoidCallback onTap;

  bool get _canAfford => userTokens >= teller.tokenCost;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: _canAfford ? onTap : null,
      child: Opacity(
        opacity: _canAfford ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: teller.highlight
                  ? [
                      teller.accentColor.withValues(alpha: 0.22),
                      const Color(0xFF1C1430),
                      faloraGold.withValues(alpha: 0.08),
                    ]
                  : [
                      teller.accentColor.withValues(alpha: 0.14),
                      const Color(0xFF151020),
                    ],
            ),
            border: Border.all(
              color: teller.highlight
                  ? faloraGold.withValues(alpha: 0.38)
                  : teller.accentColor.withValues(alpha: 0.28),
            ),
            boxShadow: teller.highlight
                ? [
                    BoxShadow(
                      color: teller.accentColor.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FortuneTellerAvatar(
                    teller: teller,
                    size: 80,
                    borderWidth: 2.5,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (teller.badge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: faloraGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: faloraGold.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              teller.badge!,
                              style: const TextStyle(
                                color: faloraGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          teller.name,
                          style: const TextStyle(
                            color: faloraTextPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          teller.title,
                          style: TextStyle(
                            color: teller.accentColor.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: faloraGold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.toll, color: faloraGold, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${teller.tokenCost}',
                          style: const TextStyle(
                            color: faloraGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                teller.bio,
                style: const TextStyle(
                  color: faloraTextSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                teller.lengthLabel,
                style: TextStyle(
                  color: teller.accentColor.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: _canAfford
                      ? LinearGradient(
                          colors: [
                            teller.accentColor,
                            teller.accentColor.withValues(alpha: 0.75),
                          ],
                        )
                      : null,
                  color: _canAfford ? null : Colors.white.withValues(alpha: 0.06),
                  border: _canAfford
                      ? null
                      : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                alignment: Alignment.center,
                child: Text(
                  _canAfford
                      ? '${teller.name} ile Devam Et'
                      : 'Yetersiz jeton (${teller.tokenCost} gerekli)',
                  style: TextStyle(
                    color: _canAfford ? Colors.white : faloraTextSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
