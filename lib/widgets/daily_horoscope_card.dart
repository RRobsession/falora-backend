import 'package:falora/services/daily_horoscope_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

/// Ana sayfa / bildirim için günlük burç kartı.
class DailyHoroscopeCard extends StatefulWidget {
  const DailyHoroscopeCard({
    super.key,
    required this.zodiac,
  });

  final String zodiac;

  @override
  State<DailyHoroscopeCard> createState() => _DailyHoroscopeCardState();
}

class _DailyHoroscopeCardState extends State<DailyHoroscopeCard> {
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = DailyHoroscopeService.instance.textForZodiac(
      zodiac: widget.zodiac,
    );
  }

  @override
  void didUpdateWidget(covariant DailyHoroscopeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zodiac != widget.zodiac) {
      _future = DailyHoroscopeService.instance.textForZodiac(
        zodiac: widget.zodiac,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final text = snap.data?.trim();
        if (text == null || text.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(FaloraRadius.lg),
              onTap: () => showDailyHoroscopeDialog(
                context,
                zodiac: widget.zodiac,
                text: text,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: faloraParchmentDecoration(
                  base: Color.lerp(faloraParchmentCard, faloraGold, 0.08)!,
                  radius: FaloraRadius.lg,
                  raised: true,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugünkü ${widget.zodiac} yorumun',
                      style: FaloraTypography.titleLarge.copyWith(
                        fontSize: 15,
                        color: faloraInkHeading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: faloraTextSecondary,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Devamını oku',
                      style: TextStyle(
                        color: faloraBronzeDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showDailyHoroscopeDialog(
  BuildContext context, {
  required String zodiac,
  required String text,
  String? dateKey,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: faloraParchmentCard,
        title: Text(
          dateKey == null
              ? '$zodiac — bugünkü yorum'
              : '$zodiac — ${DailyHoroscopeService.formatDateKeyForDisplay(dateKey)}',
        ),
        content: SingleChildScrollView(
          child: Text(
            text,
            style: const TextStyle(
              color: faloraTextPrimary,
              height: 1.45,
              fontSize: 15,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      );
    },
  );
}
