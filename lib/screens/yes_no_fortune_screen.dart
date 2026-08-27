import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/models/tarot_card.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:falora/services/tarot_deck_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/services/yes_no_fortune_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/falora_component_library.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:falora/widgets/tarot_card_picker_sheet.dart';
import 'package:falora/widgets/tarot_card_widgets.dart';
import 'package:flutter/material.dart';

const yesNoFortuneCost = 20;
const yesNoCardCount = 3;

class YesNoFortuneScreen extends StatefulWidget {
  const YesNoFortuneScreen({
    super.key,
    required this.onOpenShop,
  });

  final VoidCallback onOpenShop;

  @override
  State<YesNoFortuneScreen> createState() => _YesNoFortuneScreenState();
}

class _YesNoFortuneScreenState extends State<YesNoFortuneScreen> {
  final _questionController = TextEditingController();
  final _service = const YesNoFortuneService();
  List<TarotCardSelection> _cards = const [];
  bool _busy = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _chooseCards() async {
    final selected = await showTarotCardPickerSheet(
      context,
      initialSelection: _cards,
      selectionCount: yesNoCardCount,
      title: 'Evet / Hayır Kartlarını Seç',
      allowReset: false,
    );
    if (selected != null && mounted) setState(() => _cards = selected);
  }

  Future<void> _chooseRandom() async {
    try {
      final deck = TarotDeckService.instance.shuffledDeck(
        await TarotDeckService.instance.loadDeck(),
      );
      if (deck.length < yesNoCardCount) {
        throw StateError('Yeterli kart bulunamadı');
      }
      final random = Random();
      if (!mounted) return;
      setState(() {
        _cards = [
          for (var i = 0; i < yesNoCardCount; i++)
            TarotCardSelection.fromDefinition(
              deck[i],
              spreadPosition: i + 1,
              isReversed: random.nextBool(),
            ),
        ];
      });
    } catch (_) {
      if (mounted) _message('Tarot destesi yüklenemedi.');
    }
  }

  bool _validate() {
    if (_questionController.text.trim().length < 5) {
      _message('Lütfen en az 5 karakterlik bir soru yazın.');
      return false;
    }
    if (_cards.length != yesNoCardCount) {
      _message('Lütfen 3 tarot kartı seçin.');
      return false;
    }
    return true;
  }

  Future<void> _submit({required bool withAd}) async {
    if (_busy || !_validate()) return;
    if (!withAd) {
      final balance = TokenService.instance.liveUser.value?.tokens ?? 0;
      if (balance < yesNoFortuneCost) {
        _message('Bu fal için $yesNoFortuneCost jeton gerekiyor.');
        widget.onOpenShop();
        return;
      }
    } else {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _message('Reklam istatistiği için yeniden giriş yapmalısınız.');
        return;
      }
      final adResult = await RewardedAdService.instance.watchForUnlock(
        context: context,
        userId: userId,
      );
      if (!mounted || adResult != RewardedAdResult.rewarded) {
        if (mounted) {
          _message(RewardedAdService.instance.lastErrorMessage ??
              'Falı açmak için reklamı tamamlamalısınız.');
        }
        return;
      }
    }

    setState(() => _busy = true);
    // Çok hızlı yanıtta geçişin ani görünmesini önle; hazır sonucu yapay olarak
    // beş saniye kilitleme.
    final minimumWait = Future<void>.delayed(
      const Duration(milliseconds: 1200),
    );
    try {
      final resultFuture = _service.generate(
        question: _questionController.text,
        cards: _cards,
        paidWithAd: withAd,
      );
      final result = await resultFuture;
      await minimumWait;
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => YesNoFortuneResultScreen(
            question: _questionController.text.trim(),
            cards: _cards,
            result: result,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _message(e is YesNoFortuneException ? e.message : 'Fal yorumlanamadı.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evet / Hayır Falı')),
      body: FaloraBackground(
        child: _busy
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: faloraGold),
                    SizedBox(height: 18),
                    Text('Evet / Hayır falınız yorumlanıyor…'),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Sorunu sor', style: FaloraTypography.sectionHeading),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _questionController,
                    maxLength: 500,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Örn: Yakın zamanda beklediğim haber gelecek mi?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _cards.isEmpty ? _chooseCards : null,
                          icon: const Icon(Icons.style_outlined),
                          label: const Text('Kartları Seç'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _cards.isEmpty ? _chooseRandom : null,
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Rastgele Seç'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_cards.isEmpty)
                    const Center(child: Text('Henüz kart seçilmedi (0/3)'))
                  else
                    TarotSelectedCardsStrip(cards: _cards),
                  const SizedBox(height: 24),
                  FaloraPrimaryButton(
                    label: '$yesNoFortuneCost Jetonla Yorumla',
                    icon: Icons.auto_awesome,
                    onPressed: () => _submit(withAd: false),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _submit(withAd: true),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Reklam İzle, Ücretsiz Yorumla'),
                  ),
                ],
              ),
      ),
    );
  }
}

class YesNoFortuneResultScreen extends StatelessWidget {
  const YesNoFortuneResultScreen({
    super.key,
    required this.question,
    required this.cards,
    required this.result,
  });
  final String question;
  final List<TarotCardSelection> cards;
  final String result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Falınız Hazır')),
      body: FaloraBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(question, style: FaloraTypography.sectionHeading),
            const SizedBox(height: 18),
            TarotResultCardsGrid(cards: cards),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: faloraParchmentDecoration(),
              child: Text(result, style: FaloraTypography.bodyLarge),
            ),
            const SizedBox(height: 14),
            Text(
              'Bu fal yalnızca eğlence amaçlıdır; profesyonel tavsiye veya kesin bir gelecek öngörüsü niteliği taşımaz.',
              textAlign: TextAlign.center,
              style: FaloraTypography.bodyMedium.copyWith(
                color: faloraInkSoft,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
