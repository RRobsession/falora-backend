import 'dart:async';

import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/config/manual_fortune_config.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/models/fortune_teller_models.dart';
import 'package:falora/models/manual_fortune_reader.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/live_token_builder.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:falora/widgets/fortune_teller_avatar.dart';
import 'package:falora/widgets/manual_fortune_reader_avatar.dart';
import 'package:falora/services/manual_reader_quota_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Fal türü seçildikten sonra falcı seçim ekranı.
class FortuneTellerSelectionPage extends StatefulWidget {
  const FortuneTellerSelectionPage({
    super.key,
    required this.category,
    required this.onTellerChosen,
    required this.onManualReaderChosen,
    required this.onOpenShop,
  });

  final FortuneCategory category;
  final void Function(BuildContext context, FortuneTeller teller) onTellerChosen;
  final void Function(BuildContext context, ManualFortuneReader reader)
      onManualReaderChosen;
  final VoidCallback onOpenShop;

  @override
  State<FortuneTellerSelectionPage> createState() =>
      _FortuneTellerSelectionPageState();
}

class _FortuneTellerSelectionPageState extends State<FortuneTellerSelectionPage> {
  ManualFortuneOffer? _manualOffer;
  Timer? _manualReaderHoursTimer;
  StreamSubscription<ManualReaderDailyQuota>? _quotaSub;
  ManualReaderDailyQuota _quota = ManualReaderDailyQuota.empty;
  String? _quotaDayKey;

  void _bindQuotaStream() {
    final dayKey = ManualReaderQuotaService.instance.quotaDayKey();
    if (_quotaDayKey == dayKey && _quotaSub != null) return;
    _quotaDayKey = dayKey;
    _quotaSub?.cancel();
    _quotaSub = ManualReaderQuotaService.instance.watchDay(dayKey).listen(
      (quota) {
        if (mounted) setState(() => _quota = quota);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (supportsManualFortuneReaders(widget.category)) {
      _manualOffer = manualOfferFor(widget.category);
      logManualReaderConfig(widget.category);
      _bindQuotaStream();
      _manualReaderHoursTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) {
          if (!mounted) return;
          _bindQuotaStream();
          setState(() {});
        },
      );
    }
  }

  @override
  void dispose() {
    _quotaSub?.cancel();
    _manualReaderHoursTimer?.cancel();
    super.dispose();
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
                          _manualOffer != null
                              ? 'Yorumcular jeton ile kişisel yorum hazırlar. '
                                  'Serdar ve Hatice birebir özel yorum sunar; '
                                  '${_manualOffer!.questionLimit} soru '
                                  '${_manualOffer!.tokenCost} jeton.'
                              : 'Yorumcular jeton ile kişisel yorum hazırlar.',
                          style: FaloraTypography.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        FaloraTappableTokenBalance(
                          tokens: tokens,
                          onTap: widget.onOpenShop,
                          showLabel: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const FaloraSectionHeading('Yorumcular'),
                const SizedBox(height: 12),
                ...fortuneTellersForCategory(category).map(
                  (teller) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FortuneTellerCard(
                      teller: teller,
                      userTokens: tokens,
                      onTap: () {
                        logFortuneSelectedCost(category, teller.id);
                        widget.onTellerChosen(context, teller);
                      },
                    ),
                  ),
                ),
                if (_manualOffer != null) ...[
                  const SizedBox(height: 8),
                  const FaloraSectionHeading('Özel Yorumcular'),
                  const SizedBox(height: 12),
                  _ManualReaderHoursInfoBanner(
                    isActive: isManualReaderActiveNow,
                  ),
                  const SizedBox(height: 12),
                  ...manualFortuneReaders.map(
                    (reader) {
                      final dailyCount = _quota.countFor(reader.id);
                      final hoursActive = isManualReaderActiveNow;
                      final quotaAvailable =
                          isManualReaderQuotaAvailable(dailyCount);
                      final readerActive = hoursActive && quotaAvailable;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ManualFortuneReaderCard(
                          reader: reader,
                          category: category,
                          offer: _manualOffer!,
                          dailyCount: dailyCount,
                          isActive: readerActive,
                          onTap: () {
                            if (!hoursActive) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(manualReaderInactiveInfo),
                                ),
                              );
                              return;
                            }
                            if (!quotaAvailable) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    manualReaderQuotaFullInfo(reader.name),
                                  ),
                                ),
                              );
                              return;
                            }
                            widget.onManualReaderChosen(context, reader);
                          },
                        ),
                      );
                    },
                  ),
                ],
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
    required this.dailyCount,
    required this.isActive,
    required this.onTap,
  });

  final ManualFortuneReader reader;
  final FortuneCategory category;
  final ManualFortuneOffer offer;
  final int dailyCount;
  final bool isActive;
  final VoidCallback onTap;

  static const _avatarSize = 64.0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1 : 0.72,
      child: ScaleTap(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: faloraParchmentDecoration(
          base: Color.lerp(faloraParchmentCard, reader.accentColor, 0.08)!,
          radius: FaloraRadius.lg,
          raised: true,
          borderWidth: 1.2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ManualFortuneReaderAvatar(
                  reader: reader,
                  size: _avatarSize,
                  borderWidth: 2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ManualReaderBadge(label: manualReaderBadgeLabel),
                      const SizedBox(height: 5),
                      Text(
                        reader.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: faloraInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reader.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FaloraTypography.labelSmall.copyWith(
                          color: faloraInkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CompactQuotaBadge(count: dailyCount),
                    const SizedBox(height: 6),
                    _CompactTokenPriceBadge(amount: offer.tokenCost),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              reader.bio,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: FaloraTypography.bodyMedium.copyWith(
                color: faloraTextSecondary,
                fontSize: 12.5,
                height: 1.32,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    label: manualReaderActiveHoursLabel,
                    color: reader.accentColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _InfoChip(
                    label: isActive
                        ? 'Şu an aktif'
                        : (dailyCount >= manualReaderDailyQuotaCloseAt
                            ? 'Kota doldu'
                            : 'Şu an kapalı'),
                    color: isActive
                        ? const Color(0xFF2E7D32)
                        : faloraBronze,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    label: offer.questionLabel,
                    color: reader.accentColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _InfoChip(
                    label: offer.intentionLabel,
                    color: faloraBronze,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ManualReaderContinueButton(
              label: !isManualReaderQuotaAvailable(dailyCount)
                  ? 'Günlük kota doldu'
                  : isActive
                      ? 'Devam Et · ${offer.priceLabel}'
                      : 'Şu an aktif değil',
              onPressed: onTap,
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _ManualReaderHoursInfoBanner extends StatelessWidget {
  const _ManualReaderHoursInfoBanner({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isActive ? const Color(0xFF2E7D32) : faloraBronze)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isActive ? const Color(0xFF2E7D32) : faloraBronze)
              .withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(
            FontAwesomeIcons.clock,
            size: 16,
            color: isActive ? const Color(0xFF2E7D32) : faloraBronzeDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isActive ? manualReaderActiveNowInfo : manualReaderInactiveInfo,
              style: FaloraTypography.bodyMedium.copyWith(
                color: faloraInkHeading,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualReaderBadge extends StatelessWidget {
  const _ManualReaderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: faloraSealPreparingBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: faloraBronze.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: FaloraTypography.labelSmall.copyWith(
          color: faloraInkHeading,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

class _CompactQuotaBadge extends StatelessWidget {
  const _CompactQuotaBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: faloraParchmentInset.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: faloraBronze.withValues(alpha: 0.45)),
      ),
      child: Text(
        manualReaderQuotaLabel(count),
        style: FaloraTypography.labelLarge.copyWith(
          color: faloraInk,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _CompactTokenPriceBadge extends StatelessWidget {
  const _CompactTokenPriceBadge({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: faloraParchmentInset.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: faloraGoldDark.withValues(alpha: 0.55)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(
            FontAwesomeIcons.coins,
            size: 10,
            color: faloraBronzeDark,
          ),
          const SizedBox(height: 2),
          Text(
            '$amount',
            style: FaloraTypography.labelLarge.copyWith(
              color: faloraInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Text(
            'jeton',
            style: FaloraTypography.labelSmall.copyWith(
              color: faloraInkSoft,
              fontSize: 8,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualReaderContinueButton extends StatelessWidget {
  const _ManualReaderContinueButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(FaloraRadius.md),
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FaloraRadius.md),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [faloraBronze, faloraBronzeDark],
            ),
            border: Border.all(color: faloraGoldDark, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FaloraTypography.labelLarge.copyWith(
                color: faloraParchmentRaised,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: FaloraTypography.labelSmall.copyWith(
          color: faloraInkHeading,
          fontSize: 10,
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
