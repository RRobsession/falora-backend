import 'dart:ui' as ui;

import 'package:falora/config/playing_card_names.dart';
import 'package:falora/models/playing_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// `assets/playing_cards/` altındaki gerçek kart görsellerinden desteyi yükler.
class PlayingCardDeckService {
  PlayingCardDeckService._();

  static final PlayingCardDeckService instance = PlayingCardDeckService._();

  static const _assetPrefix = 'assets/playing_cards/';
  static final RegExp _imageExtension = RegExp(
    r'\.(svg|png|webp)$',
    caseSensitive: false,
  );

  static const _suits = [
    (PlayingSuit.hearts, 'h'),
    (PlayingSuit.diamonds, 'd'),
    (PlayingSuit.clubs, 'c'),
    (PlayingSuit.spades, 's'),
  ];

  static const _ranks = [
    'a',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'j',
    'q',
    'k',
  ];

  List<PlayingCardDefinition>? _cachedDeck;
  Future<List<PlayingCardDefinition>>? _loading;
  double? _cachedAspectRatio;

  double get cardAspectRatio =>
      _cachedAspectRatio ?? playingCardAspectRatio;

  void resetCache() {
    _cachedDeck = null;
    _loading = null;
    _cachedAspectRatio = null;
  }

  Future<List<PlayingCardDefinition>> loadDeck({bool forceReload = false}) {
    if (forceReload) resetCache();
    return _loading ??= _loadDeckInternal();
  }

  Future<List<PlayingCardDefinition>> _loadDeckInternal() async {
    if (_cachedDeck != null && _cachedDeck!.isNotEmpty) {
      return _cachedDeck!;
    }

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final available = manifest
        .listAssets()
        .where((path) => path.startsWith(_assetPrefix) && _imageExtension.hasMatch(path))
        .toSet();

    final cards = <PlayingCardDefinition>[];
    var index = 0;
    for (final (suit, code) in _suits) {
      for (final rank in _ranks) {
        final id = '${code}_$rank';
        final assetPath = playingAssetPathForId(id);
        if (!available.contains(assetPath)) {
          debugPrint('PLAYING CARD MISSING: $assetPath');
          continue;
        }
        cards.add(
          PlayingCardDefinition(
            id: id,
            suit: suit,
            rank: rank,
            assetPath: assetPath,
            deckIndex: index++,
          ),
        );
      }
    }

    if (cards.isEmpty) {
      debugPrint(
        'PLAYING DECK ERROR: no cards under assets/playing_cards — '
        'add folder to pubspec.yaml and full restart (R)',
      );
      _cachedDeck = const [];
      _loading = null;
      return _cachedDeck!;
    }

    await _resolveAspectRatio(cards.first.assetPath);

    debugPrint(
      'PLAYING DECK LOADED: ${cards.length} cards from assets/playing_cards',
    );
    if (cards.length != playingExpectedDeckSize) {
      debugPrint(
        'PLAYING DECK WARNING: expected $playingExpectedDeckSize cards, '
        'found ${cards.length}',
      );
    }

    _cachedDeck = cards;
    return cards;
  }

  List<PlayingCardDefinition> shuffledDeck(List<PlayingCardDefinition> source) {
    final copy = List<PlayingCardDefinition>.from(source)..shuffle();
    return copy;
  }

  PlayingCardDefinition? findById(String id) {
    final deck = _cachedDeck;
    if (deck == null) return null;
    for (final card in deck) {
      if (card.id == id) return card;
    }
    return null;
  }

  Future<void> _resolveAspectRatio(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final width = frame.image.width.toDouble();
      final height = frame.image.height.toDouble();
      frame.image.dispose();

      if (width <= 0 || height <= 0) return;

      _cachedAspectRatio = width / height;
      debugPrint(
        'PLAYING CARD ASPECT RATIO: $_cachedAspectRatio (${width.toInt()}x${height.toInt()})',
      );
    } catch (e) {
      debugPrint(
        'PLAYING CARD ASPECT RATIO fallback: $playingCardAspectRatio ($e)',
      );
    }
  }
}
