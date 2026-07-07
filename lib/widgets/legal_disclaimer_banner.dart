import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';

/// Fal sonuçları ve paylaşımlar için eğlence / AI feragatı.
class LegalDisclaimerBanner extends StatelessWidget {
  const LegalDisclaimerBanner({
    super.key,
    this.isManualPremium = false,
    this.compact = false,
    this.micro = false,
  });

  final bool isManualPremium;
  final bool compact;
  final bool micro;

  static const aiDisclaimerText =
      'Bu yorum yapay zeka destekli sistemlerle oluşturulmuştur. '
      'Eğlence ve kişisel farkındalık amaçlıdır; kesin sonuç, tıbbi, '
      'hukuki veya finansal tavsiye niteliği taşımaz.';

  static String disclaimerText({required bool isManualPremium}) {
    if (isManualPremium) return '';
    return aiDisclaimerText;
  }

  static String shareFooterText({required bool isManualPremium}) {
    if (isManualPremium) return '';
    return aiDisclaimerText;
  }

  @override
  Widget build(BuildContext context) {
    if (isManualPremium) return const SizedBox.shrink();

    final text = aiDisclaimerText;

    if (micro) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: faloraInkSoft.withValues(alpha: 0.45),
            fontSize: 8,
            height: 1.25,
            letterSpacing: 0.1,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: faloraBronze.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(FaloraRadius.md),
        border: Border.all(color: faloraBronze.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: compact ? 16 : 18,
            color: faloraBronzeDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: FaloraTypography.bodyMedium.copyWith(
                color: faloraInkSoft,
                fontSize: compact ? 11.5 : 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
