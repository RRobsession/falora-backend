import 'dart:ui' as ui;

import 'package:falora/models/tarot_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// `assets/tarot/` altındaki görsel dosyalarından desteyi yükler.
class TarotDeckService {
  TarotDeckService._();

  static final TarotDeckService instance = TarotDeckService._();

  static const _tarotPrefix = 'assets/tarot/';
  static final RegExp _imageExtension = RegExp(
    r'\.(jpe?g|png|webp)$',
    caseSensitive: false,
  );

  List<TarotCardDefinition>? _cachedDeck;
  Future<List<TarotCardDefinition>>? _loading;
  double? _cachedAspectRatio;

  /// İlk kart görselinden ölçülen oran; yoksa [tarotCardAspectRatioFallback].
  double get cardAspectRatio =>
      _cachedAspectRatio ?? tarotCardAspectRatioFallback;

  /// Asset manifest yenilendiyse (hot restart sonrası) tekrar yüklemek için.
  void resetCache() {
    _cachedDeck = null;
    _loading = null;
    _cachedAspectRatio = null;
  }

  Future<List<TarotCardDefinition>> loadDeck({bool forceReload = false}) {
    if (forceReload) resetCache();
    return _loading ??= _loadDeckInternal();
  }

  Future<List<TarotCardDefinition>> _loadDeckInternal() async {
    if (_cachedDeck != null && _cachedDeck!.isNotEmpty) {
      return _cachedDeck!;
    }

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();

    final tarotFolderAssets = allAssets
        .where((path) => path.startsWith(_tarotPrefix))
        .toList()
      ..sort();

    debugPrint('TAROT ASSETS FOUND: ${tarotFolderAssets.length}');
    for (final path in tarotFolderAssets) {
      debugPrint('TAROT ASSET: $path');
    }

    final imagePaths = tarotFolderAssets.where(_isTarotImageAsset).toList()
      ..sort();

    debugPrint('TAROT IMAGE ASSETS: ${imagePaths.length}');

    if (imagePaths.isEmpty) {
      _logEmptyDeckReason(tarotFolderAssets);
      _cachedDeck = const [];
      _loading = null;
      return _cachedDeck!;
    }

    await _resolveAspectRatio(imagePaths.first);

    final cards = <TarotCardDefinition>[];
    for (var i = 0; i < imagePaths.length; i++) {
      final assetPath = imagePaths[i];
      final fileName = assetPath.split('/').last;
      final id = fileName.replaceAll(_imageExtension, '');
      if (id.isEmpty || id.startsWith('.')) continue;

      cards.add(
        TarotCardDefinition(
          id: id,
          assetPath: assetPath,
          deckIndex: i,
        ),
      );
    }

    debugPrint('TAROT DECK LOADED: ${cards.length} cards from assets/tarot');

    if (cards.length != tarotExpectedDeckSize) {
      debugPrint(
        'TAROT DECK WARNING: expected $tarotExpectedDeckSize cards, '
        'found ${cards.length}',
      );
    }

    _cachedDeck = cards;
    return cards;
  }

  void _logEmptyDeckReason(List<String> tarotFolderAssets) {
    if (tarotFolderAssets.isEmpty) {
      debugPrint(
        'TAROT DECK ERROR: assets/tarot not in AssetManifest — '
        'add "assets/tarot/" to pubspec.yaml and run full restart (R)',
      );
      return;
    }

    debugPrint(
      'TAROT DECK ERROR: ${tarotFolderAssets.length} file(s) under assets/tarot '
      'but none matched .jpg/.jpeg/.png/.webp',
    );
    debugPrint(
      'TAROT DECK HINT: if you added images while the app was running, '
      'press R (hot restart) or stop and re-run flutter run',
    );
  }

  List<TarotCardDefinition> shuffledDeck(List<TarotCardDefinition> source) {
    final copy = List<TarotCardDefinition>.from(source)..shuffle();
    return copy;
  }

  TarotCardDefinition? findById(String id) {
    final deck = _cachedDeck;
    if (deck == null) return null;
    for (final card in deck) {
      if (card.id == id) return card;
    }
    return null;
  }

  bool _isTarotImageAsset(String path) {
    if (!path.startsWith(_tarotPrefix)) return false;
    final fileName = path.split('/').last;
    if (fileName.isEmpty || fileName.startsWith('.')) return false;
    return _imageExtension.hasMatch(fileName);
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
        'TAROT CARD ASPECT RATIO: $_cachedAspectRatio (${width.toInt()}x${height.toInt()})',
      );
    } catch (e) {
      debugPrint(
        'TAROT CARD ASPECT RATIO fallback: $tarotCardAspectRatioFallback ($e)',
      );
    }
  }
}
