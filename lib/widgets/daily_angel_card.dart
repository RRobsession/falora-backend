import 'dart:async';

import 'package:falora/services/daily_angel_card_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

class DailyAngelCard extends StatefulWidget {
  const DailyAngelCard({super.key, required this.userId});

  final String userId;

  @override
  State<DailyAngelCard> createState() => _DailyAngelCardState();
}

class _DailyAngelCardState extends State<DailyAngelCard> {
  Timer? _midnightTimer;
  late Stream<DailyAngelCardData?> _stream;

  @override
  void initState() {
    super.initState();
    _stream = DailyAngelCardService.instance.watchToday(widget.userId);
    _armMidnightRefresh();
  }

  @override
  void didUpdateWidget(covariant DailyAngelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _stream = DailyAngelCardService.instance.watchToday(widget.userId);
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _armMidnightRefresh() {
    _midnightTimer?.cancel();
    final shifted = DateTime.now().toUtc().add(const Duration(hours: 3));
    final nextMidnightUtc = DateTime.utc(
      shifted.year,
      shifted.month,
      shifted.day + 1,
    ).subtract(const Duration(hours: 3));
    final delay = nextMidnightUtc.difference(DateTime.now().toUtc());
    _midnightTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _stream = DailyAngelCardService.instance.watchToday(widget.userId);
      });
      _armMidnightRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyAngelCardData?>(
      stream: _stream,
      builder: (context, snapshot) {
        final card = snapshot.data;
        if (card == null || !card.isValid) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(FaloraRadius.lg),
              onTap: () => _showCard(context, card),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: faloraParchmentDecoration(
                  base: Color.lerp(faloraParchmentCard, faloraAccent, 0.08)!,
                  radius: FaloraRadius.lg,
                  raised: true,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: FaloraTypography.titleLarge.copyWith(
                        fontSize: 15,
                        color: faloraInkHeading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      card.text,
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
                      'Kartını aç',
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

  Future<void> _showCard(
    BuildContext context,
    DailyAngelCardData card,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: faloraParchmentCard,
        title: Text(card.title),
        content: SingleChildScrollView(
          child: Text(
            card.text,
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
      ),
    );
  }
}
