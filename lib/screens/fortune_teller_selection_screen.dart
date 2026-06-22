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
                          'Yorumcunu Seç',
                          style: FaloraTypography.labelLarge.copyWith(
                            color: faloraBronzeDark,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Yorumcular jeton ile kişisel yorum hazırlar. '
                          'Serdar ve Hatice birebir özel yorum sunar; '
                          '${_manualOffer.questionLimit} soru ${_manualOffer.tokenCost} jeton.',
                          style: FaloraTypography.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        FaloraTokenMedallion(
                          tokens: tokens,
                          compact: false,
                          showLabel: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const FaloraSectionHeading('Yorumcular'),
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
                const FaloraSectionHeading('Özel Yorumcular'),
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
        decoration: faloraParchmentDecoration(
          base: Color.lerp(faloraParchmentCard, reader.accentColor, 0.1)!,
          radius: FaloraRadius.xl,
          raised: true,
          borderWidth: 1.3,
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
                          color: faloraParchmentInset.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: faloraBronze.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          manualReaderBadgeLabel,
                          style: FaloraTypography.labelSmall.copyWith(
                            color: faloraBronzeDark,
                            fontSize: 11,
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
                FaloraAncientPriceBadge(
                  amount: offer.tokenCost,
                  suffix: 'jeton',
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
                  color: faloraBronze,
                ),
              ],
            ),
            const SizedBox(height: 14),
            FaloraPrimaryButton(
              label: 'Devam Et · ${offer.priceLabel}',
              onPressed: onTap,
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: FaloraTypography.labelSmall.copyWith(
          color: faloraInkHeading,
          fontSize: 11,
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
          decoration: faloraParchmentDecoration(
            base: Color.lerp(
              faloraParchmentCard,
              teller.accentColor,
              teller.highlight ? 0.12 : 0.06,
            )!,
            radius: FaloraRadius.xl,
            raised: true,
            borderWidth: teller.highlight ? 1.4 : 1.2,
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
                              style: FaloraTypography.labelSmall.copyWith(
                                color: faloraBronzeDark,
                                fontSize: 11,
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
                          style: FaloraTypography.bodyMedium.copyWith(
                            color: faloraInkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FaloraAncientPriceBadge(amount: teller.tokenCost),
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
                style: FaloraTypography.labelSmall.copyWith(
                  color: faloraInkMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FaloraRadius.md),
                  gradient: _canAfford
                      ? const LinearGradient(
                          colors: [faloraBronze, faloraBronzeDark],
                        )
                      : null,
                  color: _canAfford ? null : faloraParchmentMid,
                  border: Border.all(
                    color: _canAfford
                        ? faloraGold
                        : faloraBronze.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  _canAfford
                      ? '${teller.name} ile Devam Et'
                      : 'Yetersiz jeton (${teller.tokenCost} gerekli)',
                  style: FaloraTypography.labelLarge.copyWith(
                    color: _canAfford ? faloraParchmentRaised : faloraInkMuted,
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
