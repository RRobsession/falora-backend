import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:falora/models/bakla_scatter.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';

/// Bakla dökme animasyonunu oynatır; bitince saçılım özetini döner.
Future<BaklaScatterReading?> showBaklaFortuneSimulation(BuildContext context) {
  return Navigator.of(context).push<BaklaScatterReading?>(
    PageRouteBuilder<BaklaScatterReading?>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => const BaklaFortuneSimulationPage(),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

// ─── Zaman çizelgesi (ms) ───────────────────────────────────────────────────

abstract final class _T {
  static const handsIn = 1000;
  static const shakeEnd = 2500;
  static const pourEnd = 3500;
  static const settleEnd = 4500;
  static const symbolsEnd = 5000;
  static const total = 6200;
  static const holdAfter = 1100;
}

enum _MysticSymbol {
  heart,
  path,
  key,
  bird,
  ring,
  star,
}

class _BeanParticle {
  const _BeanParticle({
    required this.id,
    required this.palmOffset,
    required this.restPosition,
    required this.palmRotation,
    required this.restRotation,
    required this.scale,
    required this.fallDelayMs,
    required this.arcHeight,
    required this.driftX,
    required this.bouncePx,
    this.symbol,
    this.symbolOffset = const Offset(14, -10),
  });

  final int id;
  final Offset palmOffset;
  final Offset restPosition;
  final double palmRotation;
  final double restRotation;
  final double scale;
  final double fallDelayMs;
  final double arcHeight;
  final double driftX;
  final double bouncePx;
  final _MysticSymbol? symbol;
  final Offset symbolOffset;
}

class _BeanTransform {
  const _BeanTransform({
    required this.position,
    required this.rotation,
    required this.scale,
    required this.opacity,
    required this.shadowStrength,
  });

  final Offset position;
  final double rotation;
  final double scale;
  final double opacity;
  final double shadowStrength;
}

class _SceneLayout {
  const _SceneLayout({
    required this.size,
    required this.tableRect,
    required this.handsCenter,
    required this.beans,
  });

  final Size size;
  final Rect tableRect;
  final Offset handsCenter;
  final List<_BeanParticle> beans;
}

/// Sinematik bakla dökme sahnesi — realistic cartoon / storybook illüstrasyon.
class BaklaFortuneSimulationPage extends StatefulWidget {
  const BaklaFortuneSimulationPage({super.key});

  @override
  State<BaklaFortuneSimulationPage> createState() =>
      _BaklaFortuneSimulationPageState();
}

class _BaklaFortuneSimulationPageState extends State<BaklaFortuneSimulationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  _SceneLayout? _layout;
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _T.total),
    )..addListener(_onTick);
    _controller.forward();
  }

  void _onTick() {
    if (_popping || _controller.value < 1.0) return;
    _popping = true;
    final layout = _layout;
    Future<void>.delayed(const Duration(milliseconds: _T.holdAfter), () {
      if (!mounted) return;
      Navigator.of(context).pop(
        layout == null ? null : _readingFromLayout(layout),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _tMs => _controller.value * _T.total;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0904),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final layout = _layout ??= _SceneLayoutGenerator.generate(
                size,
                math.Random(),
              );

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _tMs;
                  final showInterpreting = t >= _T.symbolsEnd;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        size: size,
                        painter: _BaklaScenePainter(
                          layout: layout,
                          tMs: t,
                        ),
                      ),
                      if (t < _T.shakeEnd + 400)
                        Positioned(
                          top: 14,
                          left: 0,
                          right: 0,
                          child: Opacity(
                            opacity: (t / _T.handsIn).clamp(0.0, 1.0) * 0.9,
                            child: Text(
                              'Baklalar dökülüyor...',
                              textAlign: TextAlign.center,
                              style: FaloraTypography.bodyMedium.copyWith(
                                color: const Color(0xFFE8C88A).withValues(alpha: 0.9),
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      if (showInterpreting)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: size.height * 0.09,
                          child: Opacity(
                            opacity: ((t - _T.symbolsEnd) / 400).clamp(0.0, 1.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Falın yorumlanıyor...',
                                  textAlign: TextAlign.center,
                                  style: FaloraTypography.titleMedium.copyWith(
                                    color: const Color(0xFFF0E4C4),
                                    fontSize: 19,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

BaklaScatterReading _readingFromLayout(_SceneLayout layout) {
  return BaklaScatterReading.fromBeans(
    tableRect: layout.tableRect,
    beans: layout.beans
        .map(
          (b) => BaklaBeanPosition(
            restX: b.restPosition.dx,
            restY: b.restPosition.dy,
            symbol: b.symbol == null ? null : _symbolLabel(b.symbol!),
          ),
        )
        .toList(),
  );
}

String _symbolLabel(_MysticSymbol symbol) {
  return switch (symbol) {
    _MysticSymbol.heart => 'Kalp',
    _MysticSymbol.path => 'Yol',
    _MysticSymbol.key => 'Anahtar',
    _MysticSymbol.bird => 'Kuş',
    _MysticSymbol.ring => 'Halka',
    _MysticSymbol.star => 'Yıldız',
  };
}

// ─── Sahne üretici (procedural kümelenme) ───────────────────────────────────

abstract final class _SceneLayoutGenerator {
  static _SceneLayout generate(Size size, math.Random rng) {
    if (size.width <= 0 || size.height <= 0) {
      return _SceneLayout(
        size: const Size(360, 640),
        tableRect: const Rect.fromLTWH(20, 280, 320, 220),
        handsCenter: const Offset(180, 220),
        beans: const [],
      );
    }

    final tableRect = Rect.fromLTWH(
      size.width * 0.05,
      size.height * 0.48,
      size.width * 0.9,
      size.height * 0.36,
    );
    final handsCenter = Offset(size.width * 0.5, size.height * 0.30);
    final beans = _generateBeans(
      rng: rng,
      tableRect: tableRect,
      handsCenter: handsCenter,
    );

    return _SceneLayout(
      size: size,
      tableRect: tableRect,
      handsCenter: handsCenter,
      beans: beans,
    );
  }

  static List<_BeanParticle> _generateBeans({
    required math.Random rng,
    required Rect tableRect,
    required Offset handsCenter,
  }) {
    const count = 40;
    final restPositions = _scatterOnTable(tableRect, count, rng);

    final symbols = _MysticSymbol.values.toList()..shuffle(rng);
    final shuffledIndices = List.generate(count, (i) => i)..shuffle(rng);
    final symbolMap = <int, _MysticSymbol>{};
    for (var s = 0; s < symbols.length; s++) {
      symbolMap[shuffledIndices[s]] = symbols[s];
    }

    final beans = <_BeanParticle>[];
    for (var i = 0; i < count; i++) {
      final rest = restPositions[i];

      // Avuç içi yığın — merkeze yakın, üst üste binen küçük küme
      final layer = i % 4;
      final angle = (i / count) * math.pi * 2 + rng.nextDouble() * 0.4;
      final radius = 4 + layer * 4.5 + rng.nextDouble() * 7;
      final palmOffset = Offset(
        math.cos(angle) * radius * 0.72,
        math.sin(angle) * radius * 0.38 - 4,
      );

      final sym = symbolMap[i];
      final symSide = rest.dx < handsCenter.dx ? -1.0 : 1.0;

      // Dökülme gecikmesi: dıştakiler önce, içtekiler sonra
      final distFromCup = palmOffset.distance;
      final fallDelayMs = distFromCup * 14 + rng.nextDouble() * 120;

      // Hedefe giden yatay sapma — rest ile avuç arasındaki doğal yay
      final toRest = rest - handsCenter;
      final driftX = toRest.dx * 0.12 + (rng.nextDouble() - 0.5) * 18;

      beans.add(
        _BeanParticle(
          id: i,
          palmOffset: palmOffset,
          restPosition: rest,
          palmRotation: rng.nextDouble() * math.pi,
          restRotation: rng.nextDouble() * math.pi * 2,
          scale: 0.84 + rng.nextDouble() * 0.32,
          fallDelayMs: fallDelayMs,
          arcHeight: 28 + rng.nextDouble() * 42,
          driftX: driftX,
          bouncePx: 3 + rng.nextDouble() * 8,
          symbol: sym,
          symbolOffset: Offset(15 * symSide, -10 - rng.nextDouble() * 10),
        ),
      );
    }

    return beans;
  }

  /// Masaya eşit dağılım + hafif kümeler (Poisson-benzeri).
  static List<Offset> _scatterOnTable(Rect table, int count, math.Random rng) {
    const minDist = 12.0;
    final marginX = 28.0;
    final marginY = 22.0;
    final inner = Rect.fromLTRB(
      table.left + marginX,
      table.top + marginY,
      table.right - marginX,
      table.bottom - marginY,
    );

    final candidates = <Offset>[];
    final cols = math.max(6, (inner.width / 15).round());
    final rows = math.max(5, (inner.height / 13).round());
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final jx = (rng.nextDouble() - 0.5) * 10;
        final jy = (rng.nextDouble() - 0.5) * 8;
        candidates.add(Offset(
          inner.left + (c + 0.5) * inner.width / cols + jx,
          inner.top + (r + 0.5) * inner.height / rows + jy,
        ));
      }
    }
    candidates.shuffle(rng);

    final placed = <Offset>[];
    for (final c in candidates) {
      if (placed.length >= count) break;
      if (placed.every((p) => (p - c).distance >= minDist)) {
        placed.add(c);
      }
    }

    while (placed.length < count) {
      final p = Offset(
        inner.left + rng.nextDouble() * inner.width,
        inner.top + rng.nextDouble() * inner.height,
      );
      if (placed.every((e) => (e - p).distance >= minDist * 0.85)) {
        placed.add(p);
      }
    }

    // 3 küçük küme — yakın baklaları birbirine çek
    final clusterCenters = List.generate(
      3,
      (_) => Offset(
        inner.left + rng.nextDouble() * inner.width,
        inner.top + rng.nextDouble() * inner.height,
      ),
    );
    for (var i = 0; i < placed.length; i++) {
      if (rng.nextDouble() > 0.28) continue;
      final center = clusterCenters[rng.nextInt(clusterCenters.length)];
      final pull = 0.22 + rng.nextDouble() * 0.18;
      var pulled = Offset.lerp(placed[i], center, pull)!;
      pulled = Offset(
        pulled.dx.clamp(inner.left, inner.right),
        pulled.dy.clamp(inner.top, inner.bottom),
      );
      if (placed.every((p) => p == placed[i] || (p - pulled).distance >= minDist * 0.8)) {
        placed[i] = pulled;
      }
    }

    return placed;
  }
}

// ─── Animasyon hesabı ─────────────────────────────────────────────────────

abstract final class _BeanMotion {
  static Offset _cupPosition(_SceneLayout layout, _BeanParticle b, double tilt) {
    final slideY = tilt * 32;
    final slideX = math.sin(tilt) * 6;
    return layout.handsCenter +
        Offset(b.palmOffset.dx + slideX, b.palmOffset.dy + slideY + 6);
  }

  static Offset _pourLip(_SceneLayout layout, _BeanParticle b, double tilt) {
    return layout.handsCenter +
        Offset(
          b.palmOffset.dx * 0.55,
          30 + tilt * 48 + b.palmOffset.dy * 0.25,
        );
  }

  static _BeanTransform forBean(_BeanParticle b, _SceneLayout layout, double t) {
    final rest = b.restPosition;
    final tilt = handsTilt(t);

    if (t <= _T.handsIn) {
      final a = Curves.easeOutCubic.transform(t / _T.handsIn);
      final cup = _cupPosition(layout, b, 0);
      return _BeanTransform(
        position: cup,
        rotation: b.palmRotation,
        scale: b.scale * (0.7 + 0.3 * a),
        opacity: a,
        shadowStrength: 0.1 * a,
      );
    }

    if (t <= _T.shakeEnd) {
      final shakeT = t - _T.handsIn;
      final sway = math.sin(shakeT / 130 * math.pi * 2) * 4;
      final cup = _cupPosition(layout, b, 0);
      final jitter = Offset(
        math.sin(b.id * 1.7 + shakeT * 0.014) * 2.5,
        math.cos(b.id * 2.3 + shakeT * 0.011) * 1.8,
      );
      return _BeanTransform(
        position: cup + Offset(sway, 0) + jitter,
        rotation: b.palmRotation + math.sin(shakeT * 0.016 + b.id) * 0.18,
        scale: b.scale,
        opacity: 1,
        shadowStrength: 0.14,
      );
    }

    if (t <= _T.pourEnd) {
      final local = (t - _T.shakeEnd - b.fallDelayMs).clamp(0.0, 950.0);
      if (local <= 0) {
        final cup = _cupPosition(layout, b, tilt);
        return _BeanTransform(
          position: cup,
          rotation: b.palmRotation,
          scale: b.scale,
          opacity: 1,
          shadowStrength: 0.16,
        );
      }

      final p = (local / 950).clamp(0.0, 1.0);
      final cup = _cupPosition(layout, b, tilt * (1 - p));
      final lip = _pourLip(layout, b, tilt);

      late final Offset pos;
      late final double rot;

      if (p < 0.18) {
        final slide = Curves.easeIn.transform(p / 0.18);
        pos = Offset.lerp(cup, lip, slide)!;
        rot = ui.lerpDouble(b.palmRotation, b.palmRotation + 0.4, slide)!;
      } else {
        final fallP = Curves.easeInCubic.transform((p - 0.18) / 0.82);
        final control = Offset(
          lip.dx + b.driftX,
          lip.dy - b.arcHeight,
        );
        pos = _quadBezier(lip, control, rest, fallP);
        rot = ui.lerpDouble(b.palmRotation + 0.4, b.restRotation, fallP)!;
      }

      return _BeanTransform(
        position: pos,
        rotation: rot,
        scale: b.scale,
        opacity: 1,
        shadowStrength: 0.18 + p * 0.4,
      );
    }

    if (t <= _T.settleEnd) {
      final local = ((t - _T.pourEnd) / (_T.settleEnd - _T.pourEnd)).clamp(0.0, 1.0);
      final bounce = Curves.easeOutBack.transform(local);
      return _BeanTransform(
        position: Offset(rest.dx, rest.dy - (1 - bounce) * b.bouncePx),
        rotation: b.restRotation,
        scale: b.scale,
        opacity: 1,
        shadowStrength: 0.5 + local * 0.28,
      );
    }

    return _BeanTransform(
      position: rest,
      rotation: b.restRotation,
      scale: b.scale,
      opacity: 1,
      shadowStrength: 0.78,
    );
  }

  static Offset _quadBezier(Offset a, Offset b, Offset c, double t) {
    final ab = Offset.lerp(a, b, t)!;
    final bc = Offset.lerp(b, c, t)!;
    return Offset.lerp(ab, bc, t)!;
  }

  static double handsOpacity(double t) {
    if (t <= _T.handsIn) return Curves.easeOut.transform(t / _T.handsIn);
    if (t <= _T.pourEnd) return 1;
    if (t <= _T.settleEnd) {
      return 1 - ((t - _T.pourEnd) / (_T.settleEnd - _T.pourEnd)).clamp(0, 1) * 0.85;
    }
    return 0.12;
  }

  static double handsTilt(double t) {
    if (t < _T.shakeEnd) return 0;
    if (t > _T.pourEnd) return 0.42;
    final p = ((t - _T.shakeEnd) / (_T.pourEnd - _T.shakeEnd)).clamp(0.0, 1.0);
    return Curves.easeInOut.transform(p) * 0.42;
  }

  static double handsShake(double t) {
    if (t < _T.handsIn || t > _T.shakeEnd) {
      if (t > _T.shakeEnd && t < _T.pourEnd) {
        return math.sin((t - _T.shakeEnd) * 0.018) * 1.2;
      }
      return 0;
    }
    return math.sin((t - _T.handsIn) / 120 * math.pi * 2) * 4.5;
  }

  static double symbolReveal(double t) {
    if (t < _T.settleEnd) return 0;
    if (t >= _T.symbolsEnd) return 1;
    return Curves.easeOut.transform(
      (t - _T.settleEnd) / (_T.symbolsEnd - _T.settleEnd),
    );
  }
}

// ─── Ana sahne çizimi ───────────────────────────────────────────────────────

class _BaklaScenePainter extends CustomPainter {
  _BaklaScenePainter({required this.layout, required this.tMs});

  final _SceneLayout layout;
  final double tMs;

  @override
  void paint(Canvas canvas, Size size) {
    _CinematicBackdropPainter().paint(canvas, size);
    _WoodTablePainter(layout.tableRect).paint(canvas, size);

    final handOpacity = _BeanMotion.handsOpacity(tMs);
    final handShake = _BeanMotion.handsShake(tMs);
    final handTilt = _BeanMotion.handsTilt(tMs);
    final handScale = (0.82 + (tMs / _T.handsIn).clamp(0.0, 1.0) * 0.18);

    if (handOpacity > 0.04) {
      _CuppedHandsArt.draw(
        canvas,
        center: layout.handsCenter,
        shakeX: handShake,
        tilt: handTilt,
        opacity: handOpacity,
        scale: handScale,
      );
    }

    final transforms = layout.beans
        .map((b) => _BeanMotion.forBean(b, layout, tMs))
        .toList();

    final order = List.generate(layout.beans.length, (i) => i)
      ..sort(
        (a, b) => transforms[a].position.dy.compareTo(transforms[b].position.dy),
      );

    for (final i in order) {
      _DriedBeanArt.drawShadow(
        canvas,
        transforms[i],
        layout.beans[i].scale,
      );
    }

    for (final i in order) {
      _DriedBeanArt.drawBean(
        canvas,
        transforms[i],
        layout.beans[i].scale,
      );
    }

    final symAlpha = _BeanMotion.symbolReveal(tMs);
    if (symAlpha > 0) {
      for (var i = 0; i < layout.beans.length; i++) {
        final sym = layout.beans[i].symbol;
        if (sym == null) continue;
        final tr = transforms[i];
        final origin = tr.position + layout.beans[i].symbolOffset;
        _MysticSymbolArt.draw(
          canvas,
          sym,
          origin,
          symAlpha * tr.opacity,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BaklaScenePainter oldDelegate) {
    return oldDelegate.tMs != tMs || oldDelegate.layout != layout;
  }
}

// ─── Arka plan & masa ───────────────────────────────────────────────────────

class _CinematicBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      bg,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.1, -0.55),
          radius: 1.15,
          colors: [
            Color(0xFF3A2818),
            Color(0xFF1A1008),
            Color(0xFF080504),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(bg),
    );

    // Mum ışığı — sıcak üst aydınlatma
    canvas.drawRect(
      bg,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.75),
          radius: 0.95,
          colors: [
            const Color(0xFFFFD89A).withValues(alpha: 0.14),
            const Color(0xFFFFB45A).withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ).createShader(bg),
    );

    // Vignette
    canvas.drawRect(
      bg,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
          ],
          stops: const [0.45, 1.0],
        ).createShader(bg),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WoodTablePainter extends CustomPainter {
  _WoodTablePainter(this.tableRect);

  final Rect tableRect;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      tableRect,
      const Radius.circular(14),
    );

    canvas.drawRRect(
      rrect.shift(const Offset(0, 10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFF5C3D22),
            Color(0xFF3E2814),
            Color(0xFF2A180C),
            Color(0xFF1E1008),
          ],
          stops: const [0.0, 0.35, 0.72, 1.0],
        ).createShader(tableRect),
    );

    final rng = math.Random(tableRect.width.round() + tableRect.height.round());
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 0; i < 22; i++) {
      final y = tableRect.top + (i + 0.5) / 22 * tableRect.height;
      grain.color = Colors.black.withValues(alpha: 0.04 + rng.nextDouble() * 0.05);
      final path = Path()
        ..moveTo(tableRect.left + 8, y)
        ..cubicTo(
          tableRect.left + tableRect.width * 0.3,
          y + rng.nextDouble() * 4 - 2,
          tableRect.left + tableRect.width * 0.7,
          y + rng.nextDouble() * 4 - 2,
          tableRect.right - 8,
          y + rng.nextDouble() * 3 - 1,
        );
      canvas.drawPath(path, grain);
    }

    // Ahşap düğümler
    final knot = Paint()..color = Colors.black.withValues(alpha: 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: tableRect.center + const Offset(-40, -12),
        width: 28,
        height: 16,
      ),
      knot,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: tableRect.center + const Offset(55, 18),
        width: 20,
        height: 11,
      ),
      knot,
    );

    // Kenar aşınması / sıcak highlight
    canvas.drawRRect(
      rrect.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF8B6A3E).withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      rrect.deflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.18),
    );

    // Masa üstü mum yansıması
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFE4B5).withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.15),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(tableRect),
    );
  }

  @override
  bool shouldRepaint(covariant _WoodTablePainter oldDelegate) =>
      oldDelegate.tableRect != tableRect;
}

// ─── Tek çift kavuşturulmuş el ───────────────────────────────────────────────

abstract final class _CuppedHandsArt {
  static void draw(
    Canvas canvas, {
    required Offset center,
    required double shakeX,
    required double tilt,
    required double opacity,
    required double scale,
  }) {
    canvas.save();
    canvas.translate(center.dx + shakeX, center.dy + 8);
    canvas.scale(scale);
    canvas.rotate(tilt);

    canvas.saveLayer(
      const Rect.fromLTWH(-62, -58, 124, 130),
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );

    // Avuç gölgesi / derinlik
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 14), width: 96, height: 38),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    _drawUnifiedHands(canvas, opacity);
    canvas.restore();
    canvas.restore();
  }

  static void _drawUnifiedHands(Canvas canvas, double opacity) {
    final skin = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(-55, -35),
        const Offset(55, 55),
        const [
          Color(0xFFF4D8B6),
          Color(0xFFE2BC94),
          Color(0xFFC4956A),
        ],
        [0.0, 0.5, 1.0],
      );

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF6B4A32).withValues(alpha: 0.48 * opacity);

    final crease = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7A5640).withValues(alpha: 0.3 * opacity);

    // Sol avuç — merkeze kavuşur
    final leftCup = Path()
      ..moveTo(-4, 44)
      ..cubicTo(-20, 42, -38, 30, -46, 12)
      ..cubicTo(-52, -2, -48, -20, -36, -30)
      ..cubicTo(-28, -38, -16, -36, -10, -28)
      ..cubicTo(-14, -40, -6, -46, 0, -42)
      ..cubicTo(-8, -48, -14, -44, -16, -36)
      ..cubicTo(-22, -42, -28, -36, -26, -28)
      ..cubicTo(-34, -32, -36, -22, -30, -16)
      ..cubicTo(-38, -10, -36, 0, -28, 4)
      ..cubicTo(-34, 12, -26, 22, -16, 22)
      ..cubicTo(-12, 32, -4, 40, -4, 44)
      ..close();

    // Sağ avuç
    final rightCup = Path()
      ..moveTo(4, 44)
      ..cubicTo(20, 42, 38, 30, 46, 12)
      ..cubicTo(52, -2, 48, -20, 36, -30)
      ..cubicTo(28, -38, 16, -36, 10, -28)
      ..cubicTo(14, -40, 6, -46, 0, -42)
      ..cubicTo(8, -48, 14, -44, 16, -36)
      ..cubicTo(22, -42, 28, -36, 26, -28)
      ..cubicTo(34, -32, 36, -22, 30, -16)
      ..cubicTo(38, -10, 36, 0, 28, 4)
      ..cubicTo(34, 12, 26, 22, 16, 22)
      ..cubicTo(12, 32, 4, 40, 4, 44)
      ..close();

    final wrist = Path()
      ..moveTo(-16, 44)
      ..cubicTo(-8, 54, 8, 54, 16, 44)
      ..lineTo(12, 58)
      ..cubicTo(0, 64, -12, 58, -16, 44)
      ..close();

    canvas.drawPath(leftCup, skin);
    canvas.drawPath(rightCup, skin);
    canvas.drawPath(wrist, skin);
    canvas.drawPath(leftCup, outline);
    canvas.drawPath(rightCup, outline);

    canvas.drawPath(
      Path()
        ..moveTo(-32, 6)
        ..quadraticBezierTo(-20, -8, -6, -14)
        ..moveTo(32, 6)
        ..quadraticBezierTo(20, -8, 6, -14),
      crease,
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 12), width: 68, height: 28),
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(0, 8),
          36,
          [
            const Color(0xFFFFE8C8).withValues(alpha: 0.24 * opacity),
            Colors.transparent,
          ],
        ),
    );
  }
}

// ─── Kuru bakla ─────────────────────────────────────────────────────────────

abstract final class _DriedBeanArt {
  static const _beanW = 13.0;
  static const _beanH = 7.5;

  static void drawShadow(Canvas canvas, _BeanTransform tr, double beanScale) {
    if (tr.shadowStrength <= 0.02) return;
    canvas.save();
    canvas.translate(tr.position.dx, tr.position.dy + 2);
    canvas.rotate(tr.rotation * 0.3);
    canvas.scale(tr.scale * beanScale, tr.scale * beanScale * 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: _beanW * 1.15,
        height: _beanH * 1.4,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * tr.shadowStrength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  static void drawBean(Canvas canvas, _BeanTransform tr, double beanScale) {
    if (tr.opacity <= 0.01) return;
    canvas.save();
    canvas.translate(tr.position.dx, tr.position.dy);
    canvas.rotate(tr.rotation);
    canvas.scale(tr.scale * beanScale);

    final path = _kidneyBeanPath();
    final bounds = path.getBounds();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(bounds.left + bounds.width * 0.35, bounds.top + bounds.height * 0.3),
          bounds.width * 0.9,
          [
            const Color(0xFFC4A070).withValues(alpha: tr.opacity),
            const Color(0xFF8B5E34).withValues(alpha: tr.opacity),
            const Color(0xFF4A3018).withValues(alpha: tr.opacity),
          ],
          [0.0, 0.55, 1.0],
        ),
    );

    // Hilal çizgisi (bakla dikişi)
    canvas.drawPath(
      Path()
        ..moveTo(-2, -2)
        ..quadraticBezierTo(0, 0, 2, 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xFF3D2810).withValues(alpha: 0.45 * tr.opacity),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0xFF2A1808).withValues(alpha: 0.35 * tr.opacity),
    );

    canvas.restore();
  }

  static Path _kidneyBeanPath() {
    return Path()
      ..moveTo(-_beanW * 0.45, 0)
      ..cubicTo(-_beanW * 0.5, -_beanH * 0.65, -_beanW * 0.15, -_beanH * 0.55, _beanW * 0.35, -_beanH * 0.35)
      ..cubicTo(_beanW * 0.55, -_beanH * 0.2, _beanW * 0.52, _beanH * 0.35, _beanW * 0.2, _beanH * 0.45)
      ..cubicTo(-_beanW * 0.05, _beanH * 0.52, -_beanW * 0.48, _beanH * 0.35, -_beanW * 0.45, 0)
      ..close();
  }
}

// ─── Mistik semboller (elde çizilmiş + yumuşak glow) ────────────────────────

abstract final class _MysticSymbolArt {
  static void draw(
    Canvas canvas,
    _MysticSymbol symbol,
    Offset center,
    double alpha,
  ) {
    if (alpha <= 0.01) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    for (var i = 3; i >= 1; i--) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + i * 0.4
        ..color = const Color(0xFFE8C878).withValues(alpha: alpha * 0.08 * i)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 + i * 2.5);
      _strokeSymbol(canvas, symbol, glow);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFD4AF37).withValues(alpha: alpha * 0.85);

    _strokeSymbol(canvas, symbol, stroke);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFE8B8).withValues(alpha: alpha * 0.25);
    _fillSymbol(canvas, symbol, fill);

    canvas.restore();
  }

  static void _strokeSymbol(Canvas canvas, _MysticSymbol s, Paint paint) {
    canvas.drawPath(_pathFor(s), paint);
  }

  static void _fillSymbol(Canvas canvas, _MysticSymbol s, Paint paint) {
    if (s == _MysticSymbol.heart || s == _MysticSymbol.star) {
      canvas.drawPath(_pathFor(s), paint);
    }
  }

  static Path _pathFor(_MysticSymbol s) {
    switch (s) {
      case _MysticSymbol.heart:
        return Path()
          ..moveTo(0, 4)
          ..cubicTo(-8, -4, -12, 4, 0, 12)
          ..cubicTo(12, 4, 8, -4, 0, 4);
      case _MysticSymbol.path:
        return Path()
          ..moveTo(-10, 6)
          ..quadraticBezierTo(-2, -2, 8, -6)
          ..quadraticBezierTo(12, -8, 14, -4);
      case _MysticSymbol.key:
        return Path()
          ..addOval(Rect.fromCenter(center: const Offset(-5, -4), width: 8, height: 8))
          ..moveTo(-1, -1)
          ..lineTo(10, 8)
          ..moveTo(7, 5)
          ..lineTo(12, 5)
          ..moveTo(9, 8)
          ..lineTo(9, 2);
      case _MysticSymbol.bird:
        return Path()
          ..moveTo(-12, 2)
          ..quadraticBezierTo(-4, -8, 8, -2)
          ..quadraticBezierTo(12, 0, 6, 4)
          ..moveTo(-6, 0)
          ..quadraticBezierTo(-2, 4, 2, 2);
      case _MysticSymbol.ring:
        return Path()
          ..addOval(Rect.fromCenter(center: Offset.zero, width: 14, height: 9));
      case _MysticSymbol.star:
        return _starPath(8, 4);
    }
  }

  static Path _starPath(double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = (i * math.pi / 5) - math.pi / 2;
      final p = Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }
}
