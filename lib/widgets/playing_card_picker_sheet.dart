import 'dart:math';

import 'package:falora/config/playing_card_names.dart';
import 'package:falora/models/playing_card.dart';
import 'package:falora/services/playing_card_deck_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/falora_component_library.dart';
import 'package:falora/widgets/playing_card_widgets.dart';
import 'package:flutter/material.dart';

Future<List<PlayingCardSelection>?> showPlayingCardPickerSheet(
  BuildContext context, {
  List<PlayingCardSelection> initialSelection = const [],
}) {
  return showModalBottomSheet<List<PlayingCardSelection>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PlayingCardPickerSheet(initialSelection: initialSelection),
  );
}

class _PlayingCardPickerSheet extends StatefulWidget {
  const _PlayingCardPickerSheet({required this.initialSelection});

  final List<PlayingCardSelection> initialSelection;

  @override
  State<_PlayingCardPickerSheet> createState() => _PlayingCardPickerSheetState();
}

class _PlayingCardPickerSheetState extends State<_PlayingCardPickerSheet> {
  List<PlayingCardDefinition> _shuffledDeck = const [];
  late final Map<String, PlayingCardSelection> _selectedById;
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
      var deck = await PlayingCardDeckService.instance.loadDeck();
      if (deck.length < playingSpreadCardCount) {
        deck = await PlayingCardDeckService.instance.loadDeck(forceReload: true);
      }
      if (!mounted) return;
      if (deck.length < playingSpreadCardCount) {
        setState(() {
          _loading = false;
          _loadError =
              'Yeterli iskambil kartı bulunamadı (${deck.length}/$playingExpectedDeckSize). '
              'Uygulamayı tamamen kapatıp yeniden açın (hot restart: R).';
        });
        return;
      }
      setState(() {
        _shuffledDeck = PlayingCardDeckService.instance.shuffledDeck(deck);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'İskambil destesi yüklenemedi.';
      });
    }
  }

  List<PlayingCardSelection> get _orderedSelection {
    final list = _selectedById.values.toList()
      ..sort((a, b) => a.positionIndex.compareTo(b.positionIndex));
    return list;
  }

  void _selectCard(PlayingCardDefinition definition) {
    if (_selectedById.containsKey(definition.id)) return;
    if (_selectedById.length >= playingSpreadCardCount) return;

    setState(() {
      _selectedById[definition.id] = PlayingCardSelection.fromDefinition(
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
    if (_selectedById.length != playingSpreadCardCount) return;
    Navigator.of(context).pop(_orderedSelection);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedById.length;
    final canComplete = selectedCount == playingSpreadCardCount;
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
                            'İskambil Kartlarını Seç',
                            style: FaloraTypography.displayMedium.copyWith(
                              color: faloraInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kapalı kartlardan $playingSpreadCardCount tanesini seçin (7\'li açılım)',
                            style: FaloraTypography.bodyMedium.copyWith(
                              color: faloraInkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FaloraSelectionCounter(
                      selected: selectedCount,
                      total: playingSpreadCardCount,
                      prefix: '$selectedCount/$playingSpreadCardCount',
                    ),
                  ],
                ),
                if (selectedCount > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetSelection,
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
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: FaloraTypography.bodyMedium.copyWith(
                                color: faloraInkSoft,
                              ),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 520 ? 5 : 4;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                                childAspectRatio: PlayingCardDeckService
                                    .instance.cardAspectRatio,
                              ),
                              itemCount: _shuffledDeck.length,
                              itemBuilder: (context, index) {
                                final definition = _shuffledDeck[index];
                                final selection = _selectedById[definition.id];
                                final isSelected = selection != null;
                                final canSelect = !isSelected &&
                                    selectedCount < playingSpreadCardCount;

                                return PlayingPickerGridCard(
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
                  : 'Seçimi Tamamla ($selectedCount/$playingSpreadCardCount)',
              onPressed: canComplete ? _complete : null,
            ),
          ),
        ],
      ),
    );
  }
}
