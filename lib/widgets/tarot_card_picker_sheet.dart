import 'dart:math';

import 'package:falora/models/tarot_card.dart';
import 'package:falora/services/tarot_deck_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/falora_component_library.dart';
import 'package:falora/widgets/tarot_card_widgets.dart';
import 'package:flutter/material.dart';

/// 78 karttan 8 seçim yapan premium bottom sheet.
Future<List<TarotCardSelection>?> showTarotCardPickerSheet(
  BuildContext context, {
  List<TarotCardSelection> initialSelection = const [],
}) {
  return showModalBottomSheet<List<TarotCardSelection>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TarotCardPickerSheet(initialSelection: initialSelection),
  );
}

class _TarotCardPickerSheet extends StatefulWidget {
  const _TarotCardPickerSheet({required this.initialSelection});

  final List<TarotCardSelection> initialSelection;

  @override
  State<_TarotCardPickerSheet> createState() => _TarotCardPickerSheetState();
}

class _TarotCardPickerSheetState extends State<_TarotCardPickerSheet> {
  List<TarotCardDefinition> _shuffledDeck = const [];
  late final Map<String, TarotCardSelection> _selectedById;
  final _rng = Random();
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedById = {
      for (final c in widget.initialSelection) c.id: c,
    };
    _loadDeck();
  }

  Future<void> _loadDeck() async {
    try {
      var deck = await TarotDeckService.instance.loadDeck();
      if (deck.length < tarotSpreadCardCount) {
        deck = await TarotDeckService.instance.loadDeck(forceReload: true);
      }
      if (!mounted) return;
      if (deck.length < tarotSpreadCardCount) {
        setState(() {
          _loading = false;
          _loadError =
              'Yeterli tarot kartı bulunamadı (${deck.length}/$tarotSpreadCardCount). '
              'Uygulamayı tamamen kapatıp yeniden açın (hot restart: R).';
        });
        return;
      }
      setState(() {
        _shuffledDeck = TarotDeckService.instance.shuffledDeck(deck);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Tarot destesi yüklenemedi.';
      });
    }
  }

  List<TarotCardSelection> get _orderedSelection {
    final list = _selectedById.values.toList()
      ..sort((a, b) => a.positionIndex.compareTo(b.positionIndex));
    return list;
  }

  void _selectCard(TarotCardDefinition definition) {
    if (_selectedById.containsKey(definition.id)) return;
    if (_selectedById.length >= tarotSpreadCardCount) return;

    setState(() {
      _selectedById[definition.id] = TarotCardSelection.fromDefinition(
        definition,
        spreadPosition: _selectedById.length + 1,
        isReversed: _rng.nextBool(),
      );
    });
  }

  void _resetSelection() {
    setState(_selectedById.clear);
  }

  void _complete() {
    if (_selectedById.length != tarotSpreadCardCount) return;
    Navigator.of(context).pop(_orderedSelection);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedById.length;
    final canComplete = selectedCount == tarotSpreadCardCount;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FaloraRadius.sheet)),
        color: faloraParchmentMid,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: faloraParchmentDecoration(
              radius: 0,
              raised: false,
              goldBorder: false,
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: faloraBronze.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tarot Kartlarını Seç',
                            style: FaloraTypography.displayMedium.copyWith(
                              color: faloraInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loading
                                ? 'Deste yükleniyor…'
                                : 'Kapalı kartlardan $tarotSpreadCardCount tanesini seçin',
                            style: FaloraTypography.bodyMedium.copyWith(
                              color: faloraInkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FaloraSelectionCounter(
                      selected: selectedCount,
                      total: tarotSpreadCardCount,
                      prefix: '$selectedCount/$tarotSpreadCardCount',
                    ),
                  ],
                ),
                if (selectedCount > 0 && !_loading) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetSelection,
                      style: TextButton.styleFrom(
                        foregroundColor: faloraBronzeDark,
                      ),
                      child: const Text('Seçimi Sıfırla'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: faloraTarotTableSurfaceDecoration(),
              child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: faloraGold),
                  )
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                            style: FaloraTypography.bodyLarge.copyWith(
                              color: faloraParchmentRaised,
                            ),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns =
                              constraints.maxWidth >= 520 ? 4 : 3;
                          return GridView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 2, 12, 6),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio:
                                  TarotDeckService.instance.cardAspectRatio,
                            ),
                            itemCount: _shuffledDeck.length,
                            itemBuilder: (context, index) {
                              final definition = _shuffledDeck[index];
                              final selection = _selectedById[definition.id];
                              final isSelected = selection != null;
                              final canSelect = !isSelected &&
                                  selectedCount < tarotSpreadCardCount;

                              return TarotPickerGridCard(
                                selection: selection,
                                isSelected: isSelected,
                                canSelect: canSelect,
                                onTap: () => _selectCard(definition),
                              );
                            },
                          );
                        },
                      ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
            decoration: faloraParchmentDecoration(
              radius: 0,
              raised: false,
              goldBorder: false,
            ),
            child: FaloraPrimaryButton(
              label: canComplete
                  ? 'Seçimi Tamamla'
                  : 'Seçimi Tamamla ($selectedCount/$tarotSpreadCardCount)',
              onPressed: canComplete && !_loading ? _complete : null,
            ),
          ),
        ],
      ),
    );
  }
}
