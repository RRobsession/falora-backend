import 'dart:ui';

/// Animasyondaki bakla saçılımının AI yorumuna aktarılan özeti.
class BaklaScatterReading {
  const BaklaScatterReading({
    required this.beanCount,
    required this.densityBias,
    required this.patternTraits,
    required this.spreadSummary,
    required this.markedSymbols,
  });

  final int beanCount;
  final String densityBias;
  final List<String> patternTraits;
  final String spreadSummary;
  final List<BaklaMarkedSymbol> markedSymbols;

  factory BaklaScatterReading.fromBeans({
    required Rect tableRect,
    required List<BaklaBeanPosition> beans,
  }) {
    final norms = beans
        .map(
          (b) => Offset(
            ((b.restX - tableRect.left) / tableRect.width).clamp(0.0, 1.0),
            ((b.restY - tableRect.top) / tableRect.height).clamp(0.0, 1.0),
          ),
        )
        .toList();

    final beanCount = beans.length;
    final avgX = norms.isEmpty
        ? 0.5
        : norms.map((p) => p.dx).reduce((a, b) => a + b) / norms.length;
    final avgY = norms.isEmpty
        ? 0.5
        : norms.map((p) => p.dy).reduce((a, b) => a + b) / norms.length;

    final densityBias = _densityBias(avgX, avgY);
    final centerCount = norms
        .where((p) => p.dx > 0.38 && p.dx < 0.62 && p.dy > 0.38 && p.dy < 0.62)
        .length;
    final clusterCount = _countClusters(norms, 0.09);

    final traits = <String>[];
    if (avgX < 0.44) {
      traits.add('sola yığılma');
    } else if (avgX > 0.56) {
      traits.add('sağa yığılma');
    } else {
      traits.add('dengeli yayılım');
    }
    if (centerCount <= 2 && beanCount >= 12) {
      traits.add('merkez boşluğu');
    }
    if (clusterCount >= 2) {
      traits.add('$clusterCount küçük küme');
    }
    final soloCount = _soloBeanCount(norms, 0.085);
    if (soloCount >= 4) {
      traits.add('$soloCount tek başına bakla');
    }
    if (beans.any((b) => b.symbol == 'Yol')) {
      traits.add('yol imgesi belirdi');
    }
    if (beans.any((b) => b.symbol == 'Halka')) {
      traits.add('niyet halkası izlenimi');
    }

    final marked = <BaklaMarkedSymbol>[];
    for (var i = 0; i < beans.length; i++) {
      final symbol = beans[i].symbol;
      if (symbol == null) continue;
      final p = norms[i];
      marked.add(
        BaklaMarkedSymbol(
          symbol: symbol,
          zone: _zone(p.dx, p.dy),
          normX: _round(p.dx),
          normY: _round(p.dy),
          nearCluster: _isNearCluster(p, norms, i, 0.09),
        ),
      );
    }
    marked.sort((a, b) => a.symbol.compareTo(b.symbol));

    final spreadSummary = StringBuffer()
      ..write('Masa üzerine $beanCount bakla döküldü. ')
      ..write('$densityBias. ');
    if (traits.isNotEmpty) {
      spreadSummary.write('Öne çıkan izler: ${traits.join(', ')}. ');
    }
    if (marked.isNotEmpty) {
      spreadSummary.write(
        '${marked.length} mistik imge belirdi (${marked.map((m) => '${m.symbol} (${m.zone})').join('; ')}).',
      );
    }

    return BaklaScatterReading(
      beanCount: beanCount,
      densityBias: densityBias,
      patternTraits: traits,
      spreadSummary: spreadSummary.toString(),
      markedSymbols: marked,
    );
  }

  Map<String, dynamic> toApiMap() => {
        'beanCount': beanCount,
        'densityBias': densityBias,
        'patternTraits': patternTraits,
        'spreadSummary': spreadSummary,
        'markedSymbols': markedSymbols.map((m) => m.toApiMap()).toList(),
      };

  factory BaklaScatterReading.fromMap(Map<String, dynamic> map) {
    final rawSymbols = map['markedSymbols'];
    final symbols = rawSymbols is List
        ? rawSymbols
            .whereType<Map>()
            .map(
              (item) => BaklaMarkedSymbol.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <BaklaMarkedSymbol>[];

    return BaklaScatterReading(
      beanCount: (map['beanCount'] as num?)?.toInt() ?? 0,
      densityBias: map['densityBias'] as String? ?? '',
      patternTraits: (map['patternTraits'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      spreadSummary: map['spreadSummary'] as String? ?? '',
      markedSymbols: symbols,
    );
  }

  static String _densityBias(double avgX, double avgY) {
    final h = avgX < 0.44
        ? 'sola yığılma'
        : avgX > 0.56
            ? 'sağa yığılma'
            : 'yatayda dengeli dağılım';
    final v = avgY < 0.42
        ? 'üst bölgede yoğunlaşma'
        : avgY > 0.58
            ? 'alt bölgede yoğunlaşma'
            : 'dikeyde orta yayılım';
    return '$h, $v';
  }

  static String _zone(double x, double y) {
    final h = x < 0.33 ? 'sol' : (x > 0.66 ? 'sağ' : 'orta');
    final v = y < 0.33 ? 'üst' : (y > 0.66 ? 'alt' : 'orta');
    if (h == 'orta' && v == 'orta') return 'merkez';
    if (v == 'orta') return h;
    if (h == 'orta') return v;
    return '$h-$v';
  }

  static double _round(double v) => (v * 100).round() / 100;

  static int _countClusters(List<Offset> norms, double radius) {
    final visited = List<bool>.filled(norms.length, false);
    var clusters = 0;

    for (var i = 0; i < norms.length; i++) {
      if (visited[i]) continue;
      final stack = <int>[i];
      visited[i] = true;
      var size = 0;
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        size++;
        for (var j = 0; j < norms.length; j++) {
          if (visited[j]) continue;
          if ((norms[cur] - norms[j]).distance <= radius) {
            visited[j] = true;
            stack.add(j);
          }
        }
      }
      if (size >= 2) clusters++;
    }
    return clusters;
  }

  static int _soloBeanCount(List<Offset> norms, double radius) {
    var solo = 0;
    for (var i = 0; i < norms.length; i++) {
      final hasNeighbor = norms.asMap().entries.any(
            (e) =>
                e.key != i && (e.value - norms[i]).distance <= radius,
          );
      if (!hasNeighbor) solo++;
    }
    return solo;
  }

  static bool _isNearCluster(
    Offset p,
    List<Offset> norms,
    int index,
    double radius,
  ) {
    var neighbors = 0;
    for (var i = 0; i < norms.length; i++) {
      if (i == index) continue;
      if ((norms[i] - p).distance <= radius) neighbors++;
    }
    return neighbors >= 1;
  }
}

class BaklaBeanPosition {
  const BaklaBeanPosition({
    required this.restX,
    required this.restY,
    this.symbol,
  });

  final double restX;
  final double restY;
  final String? symbol;
}

class BaklaMarkedSymbol {
  const BaklaMarkedSymbol({
    required this.symbol,
    required this.zone,
    required this.normX,
    required this.normY,
    required this.nearCluster,
  });

  final String symbol;
  final String zone;
  final double normX;
  final double normY;
  final bool nearCluster;

  Map<String, dynamic> toApiMap() => {
        'symbol': symbol,
        'zone': zone,
        'normX': normX,
        'normY': normY,
        'nearCluster': nearCluster,
      };

  factory BaklaMarkedSymbol.fromMap(Map<String, dynamic> map) {
    return BaklaMarkedSymbol(
      symbol: map['symbol'] as String? ?? '',
      zone: map['zone'] as String? ?? '',
      normX: (map['normX'] as num?)?.toDouble() ?? 0,
      normY: (map['normY'] as num?)?.toDouble() ?? 0,
      nearCluster: map['nearCluster'] as bool? ?? false,
    );
  }
}
