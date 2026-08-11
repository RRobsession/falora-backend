import 'package:falora/config/faq_content.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';

Future<void> showFaqDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _FaqDialog(),
  );
}

class _FaqDialog extends StatelessWidget {
  const _FaqDialog();

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      backgroundColor: faloraParchmentRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(
                    Icons.help_outline_rounded,
                    color: faloraBronzeDark,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sıkça Sorulan Sorular',
                      style: TextStyle(
                        fontFamily: FaloraTypography.displayFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: faloraInkHeading,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: faloraInkMuted,
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: faloraBronze.withValues(alpha: 0.25)),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                itemCount: faloraFaqItems.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: faloraBronze.withValues(alpha: 0.12),
                ),
                itemBuilder: (context, index) {
                  final item = faloraFaqItems[index];
                  return Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: faloraBronze.withValues(alpha: 0.08),
                      highlightColor: faloraGold.withValues(alpha: 0.06),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      iconColor: faloraBronzeDark,
                      collapsedIconColor: faloraInkMuted,
                      title: Text(
                        item.question,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: faloraInkHeading,
                          height: 1.3,
                        ),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.answer,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: faloraInkSoft.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
