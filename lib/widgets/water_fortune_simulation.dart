import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:falora/models/water_scatter.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';

/// Su falı ritüel animasyonunu oynatır; bitince saçılım özetini döner.
Future<WaterScatterReading?> showWaterFortuneSimulation(BuildContext context) {
  return Navigator.of(context).push<WaterScatterReading?>(
    PageRouteBuilder<WaterScatterReading?>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => const WaterFortuneSimulationPage(),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

abstract final class _T {
  static const total = 6800;
  static const symbolsStart = 2600;
  static const symbolsEnd = 5200;
  static const interpretingStart = 5200;
  static const holdAfter = 1300;
}

enum _WaterSymbol {
  kalp('kalp'),
  kus('kuş'),
  anahtar('anahtar'),
  yol('yol'),
  ay('ay'),
  yildiz('yıldız'),
  balik('balık'),
  goz('göz'),
  halka('halka');

  const _WaterSymbol(this.label);
  final String label;
}

class _Ripple {
  const _Ripple({required this.normCenter, required this.startMs});

  final Offset normCenter;
  final double startMs;
}

class _SymbolPlacement {
  const _SymbolPlacement({
    required this.symbol,
    required this.normCenter,
    required this.scale,
    required this.rotation,
    required this.emergeDelayMs,
  });

  final _WaterSymbol symbol;
  final Offset normCenter;
  final double scale;
  final double rotation;
  final double emergeDelayMs;
}

abstract final class _MysticBowlMetrics {
  static const aspect = 0.54;
  static const waterCenterYNorm = 0.34;
  static const waterWidthNorm = 0.50;
  static const waterHeightNorm = 0.19;
}

class _SceneLayout {
  const _SceneLayout({
    required this.size,
    required this.tableRect,
    required this.bowlRect,
    required this.waterRect,
    required this.candleCenter,
    required this.symbols,
    required this.waterClarity,
    required this.reflectionStrength,
    required this.dominantSymbol,
  });

  final Size size;
  final Rect tableRect;
  final Rect bowlRect;
  final Rect waterRect;
  final Offset candleCenter;
  final List<_SymbolPlacement> symbols;
  final String waterClarity;
  final String reflectionStrength;
  final String dominantSymbol;

  Offset get bowlCenter => bowlRect.center;

  Offset waterPointFromNorm(Offset norm) {
    return Offset(
      waterRect.left + norm.dx * waterRect.width,
      waterRect.top + norm.dy * waterRect.height,
    );
  }
}

class _SceneLayoutGenerator {
  static _SceneLayout generate(Size size, math.Random rng) {
    final tableRect = Rect.fromLTWH(
      size.width * 0.06,
      size.height * 0.40,
      size.width * 0.88,
      size.height * 0.52,
    );
    final bowlWidth = size.width * 0.58;
    final bowlHeight = bowlWidth * _MysticBowlMetrics.aspect;
    final bowlRect = Rect.fromCenter(
      center: Offset(size.width * 0.52, size.height * 0.50),
      width: bowlWidth,
      height: bowlHeight,
    );
    final waterRect = Rect.fromCenter(
      center: Offset(
        bowlRect.center.dx,
        bowlRect.top + bowlHeight * _MysticBowlMetrics.waterCenterYNorm,
      ),
      width: bowlWidth * _MysticBowlMetrics.waterWidthNorm,
      height: bowlHeight * _MysticBowlMetrics.waterHeightNorm,
    );
    final candleCenter = Offset(size.width * 0.18, size.height * 0.38);

    final pool = _WaterSymbol.values.toList()..shuffle(rng);
    final symbolCount = 3 + rng.nextInt(3);
    final picked = pool.take(symbolCount).toList();

    final used = <Offset>[];
    final placements = <_SymbolPlacement>[];
    for (final symbol in picked) {
      Offset norm;
      var attempts = 0;
      do {
        norm = Offset(
          0.18 + rng.nextDouble() * 0.64,
          0.22 + rng.nextDouble() * 0.56,
        );
        attempts++;
      } while (
          attempts < 12 &&
          used.any((u) => (u - norm).distance < 0.18));
      used.add(norm);
      placements.add(
        _SymbolPlacement(
          symbol: symbol,
          normCenter: norm,
          scale: 0.85 + rng.nextDouble() * 0.35,
          rotation: (rng.nextDouble() - 0.5) * 0.5,
          emergeDelayMs: rng.nextDouble() * 900,
        ),
      );
    }

    const clarities = ['berrak', 'hafif bulanık', 'derin ve sakin'];
    const reflections = ['yüksek', 'orta', 'düşük'];

    return _SceneLayout(
      size: size,
      tableRect: tableRect,
      bowlRect: bowlRect,
      waterRect: waterRect,
      candleCenter: candleCenter,
      symbols: placements,
      waterClarity: clarities[rng.nextInt(clarities.length)],
      reflectionStrength: reflections[rng.nextInt(reflections.length)],
      dominantSymbol: picked[rng.nextInt(picked.length)].label,
    );
  }
}

class WaterFortuneSimulationPage extends StatefulWidget {
  const WaterFortuneSimulationPage({super.key});

  @override
  State<WaterFortuneSimulationPage> createState() =>
      _WaterFortuneSimulationPageState();
}

class _WaterFortuneSimulationPageState extends State<WaterFortuneSimulationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  _SceneLayout? _layout;
  final List<_Ripple> _ripples = [];
  bool _ritualStarted = false;
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _T.total),
    )..addListener(_onTick);
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

  WaterScatterReading _readingFromLayout(_SceneLayout layout) {
    final rippleCount = _ripples.isEmpty ? 1 : _ripples.length;
    return WaterScatterReading(
      symbols: layout.symbols.map((s) => s.symbol.label).toList(),
      waterClarity: layout.waterClarity,
      rippleCount: rippleCount,
      motion: WaterScatterReading.motionForRippleCount(rippleCount),
      dominantSymbol: layout.dominantSymbol,
      reflectionStrength: layout.reflectionStrength,
    );
  }

  double get _tMs =>
      _ritualStarted ? _controller.value * _T.total : 0;

  void _addRippleAt(Offset local, _SceneLayout layout) {
    final water = layout.waterRect;
    final norm = Offset(
      ((local.dx - water.left) / water.width).clamp(0.05, 0.95),
      ((local.dy - water.top) / water.height).clamp(0.08, 0.92),
    );
    setState(() {
      _ripples.add(_Ripple(normCenter: norm, startMs: _tMs));
      if (!_ritualStarted) {
        _ritualStarted = true;
        _controller.forward();
      }
    });
  }

  void _onTapDown(TapDownDetails details, _SceneLayout layout) {
    _addRippleAt(details.localPosition, layout);
  }

  void _onRitualButton(_SceneLayout layout) {
    _addRippleAt(layout.waterPointFromNorm(const Offset(0.5, 0.5)), layout);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0604),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final layout = _layout ??= _SceneLayoutGenerator.generate(
                size,
                math.Random(),
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _onTapDown(d, layout),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _tMs;
                    final showInterpreting = t >= _T.interpretingStart;
                    final waiting = !_ritualStarted;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          size: size,
                          painter: _WaterBackdropPainter(
                            layout: layout,
                            tMs: t,
                          ),
                        ),
                        CustomPaint(
                          size: size,
                          painter: _WaterBowlBodyPainter(
                            layout: layout,
                            tMs: t,
                          ),
                        ),
                        CustomPaint(
                          size: size,
                          painter: _WaterSurfacePainter(
                            layout: layout,
                            tMs: t,
                            ripples: _ripples,
                          ),
                        ),
                        CustomPaint(
                          size: size,
                          painter: _WaterBowlRimPainter(
                            layout: layout,
                            tMs: t,
                          ),
                        ),
                        if (waiting)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 28,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Eski masadaki su kasesine dokun…',
                                  textAlign: TextAlign.center,
                                  style: FaloraTypography.bodyMedium.copyWith(
                                    color: const Color(0xFFE8C88A)
                                        .withValues(alpha: 0.88),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                FilledButton(
                                  onPressed: () => _onRitualButton(layout),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF5C3D1E),
                                    foregroundColor:
                                        const Color(0xFFF5E6C8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text('Su Falına Bak'),
                                ),
                              ],
                            ),
                          ),
                        if (!waiting && t < _T.symbolsEnd)
                          Positioned(
                            top: 14,
                            left: 0,
                            right: 0,
                            child: Opacity(
                              opacity: 0.85,
                              child: Text(
                                'Suyun yüzeyi konuşuyor…',
                                textAlign: TextAlign.center,
                                style: FaloraTypography.bodyMedium.copyWith(
                                  color: const Color(0xFFE8C88A)
                                      .withValues(alpha: 0.9),
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        if (showInterpreting)
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: size.height * 0.12,
                            child: Opacity(
                              opacity: ((t - _T.interpretingStart) / 700)
                                  .clamp(0.0, 1.0),
                              child: Text(
                                'Su falın yorumlanıyor...',
                                textAlign: TextAlign.center,
                                style: FaloraTypography.bodyLarge.copyWith(
                                  color: const Color(0xFFFFE8B8),
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x66D4AF37),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WaterBackdropPainter extends CustomPainter {
  const _WaterBackdropPainter({
    required this.layout,
    required this.tMs,
  });

  final _SceneLayout layout;
  final double tMs;

  @override
  void paint(Canvas canvas, Size size) {
    _drawAmbient(canvas, size);
    _drawTable(canvas);
    _drawCandle(canvas);
    _drawVignette(canvas, size);
  }

  void _drawAmbient(Canvas canvas, Size size) {
    final bg = Offset.zero & size;
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
  }

  void _drawVignette(Canvas canvas, Size size) {
    final bg = Offset.zero & size;
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

  void _drawTable(Canvas canvas) {
    final r = layout.tableRect;
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(14));

    canvas.drawRRect(
      rrect.shift(const Offset(0, 10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5C3D22),
            Color(0xFF3E2814),
            Color(0xFF2A180C),
            Color(0xFF1E1008),
          ],
          stops: [0.0, 0.35, 0.72, 1.0],
        ).createShader(r),
    );

    final rng = math.Random(r.width.round() + r.height.round());
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 22; i++) {
      final y = r.top + (i + 0.5) / 22 * r.height;
      grain.color = Colors.black.withValues(alpha: 0.04 + rng.nextDouble() * 0.05);
      canvas.drawPath(
        Path()
          ..moveTo(r.left + 8, y)
          ..cubicTo(
            r.left + r.width * 0.3,
            y + rng.nextDouble() * 4 - 2,
            r.left + r.width * 0.7,
            y + rng.nextDouble() * 4 - 2,
            r.right - 8,
            y + rng.nextDouble() * 3 - 1,
          ),
        grain,
      );
    }

    canvas.drawRRect(
      rrect.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF8B6A3E).withValues(alpha: 0.35),
    );
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
        ).createShader(r),
    );
  }

  void _drawCandle(Canvas canvas) {
    final c = layout.candleCenter;
    final flicker = math.sin(tMs * 0.012) * 0.08 + 1.0;

    canvas.drawCircle(
      c,
      90 * flicker,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          90 * flicker,
          [
            const Color(0xFFFFD080).withValues(alpha: 0.18),
            const Color(0xFFFFA040).withValues(alpha: 0.06),
            Colors.transparent,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(0, 22), width: 16, height: 38),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFE8DCC8),
    );

    final flame = Path()
      ..moveTo(c.dx, c.dy - 8)
      ..quadraticBezierTo(c.dx - 7, c.dy - 22, c.dx, c.dy - 34 * flicker)
      ..quadraticBezierTo(c.dx + 7, c.dy - 22, c.dx, c.dy - 8);
    canvas.drawPath(
      flame,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx, c.dy - 34),
          Offset(c.dx, c.dy - 4),
          [
            const Color(0xFFFFF0C0),
            const Color(0xFFFFB040),
            const Color(0xFFFF6020).withValues(alpha: 0.6),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _WaterBackdropPainter oldDelegate) =>
      oldDelegate.tMs != tMs;
}

class _WaterBowlBodyPainter extends CustomPainter {
  const _WaterBowlBodyPainter({required this.layout, required this.tMs});

  final _SceneLayout layout;
  final double tMs;

  @override
  void paint(Canvas canvas, Size size) {
    _MysticScryingBowlArt.drawBody(
      canvas,
      bowlRect: layout.bowlRect,
      waterRect: layout.waterRect,
      tMs: tMs,
    );
  }

  @override
  bool shouldRepaint(covariant _WaterBowlBodyPainter oldDelegate) =>
      oldDelegate.tMs != tMs;
}

class _WaterBowlRimPainter extends CustomPainter {
  const _WaterBowlRimPainter({required this.layout, required this.tMs});

  final _SceneLayout layout;
  final double tMs;

  @override
  void paint(Canvas canvas, Size size) {
    _MysticScryingBowlArt.drawRim(
      canvas,
      bowlRect: layout.bowlRect,
      waterRect: layout.waterRect,
      candleCenter: layout.candleCenter,
      tMs: tMs,
    );
  }

  @override
  bool shouldRepaint(covariant _WaterBowlRimPainter oldDelegate) =>
      oldDelegate.tMs != tMs;
}

class _WaterSurfacePainter extends CustomPainter {
  const _WaterSurfacePainter({
    required this.layout,
    required this.tMs,
    required this.ripples,
  });

  final _SceneLayout layout;
  final double tMs;
  final List<_Ripple> ripples;

  @override
  void paint(Canvas canvas, Size size) {
    _drawWater(canvas);
    _drawRipples(canvas);
    _drawSymbols(canvas);
  }

  void _drawWater(Canvas canvas) {
    final water = layout.waterRect;
    final wave = math.sin(tMs * 0.004) * 2.5 + math.sin(tMs * 0.007) * 1.2;
    final clarityAlpha = switch (layout.waterClarity) {
      'berrak' => 0.92,
      'hafif bulanık' => 0.78,
      _ => 0.68,
    };

    final waterPath = Path()
      ..addOval(water.inflate(wave * 0.15));

    canvas.save();
    canvas.clipPath(waterPath);

    canvas.drawOval(
      water,
      Paint()
        ..shader = ui.Gradient.radial(
          water.center.translate(-water.width * 0.12, -water.height * 0.2),
          water.width * 0.65,
          [
            const Color(0xFF4A8AA8).withValues(alpha: clarityAlpha),
            const Color(0xFF1A3A50).withValues(alpha: clarityAlpha * 0.95),
            const Color(0xFF0A1820).withValues(alpha: 0.98),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    final reflectStrength = switch (layout.reflectionStrength) {
      'yüksek' => 0.28,
      'düşük' => 0.1,
      _ => 0.18,
    };

    for (var i = 0; i < 5; i++) {
      final phase = tMs * 0.003 + i * 1.3;
      final y = water.top + water.height * (0.25 + i * 0.14) +
          math.sin(phase) * 3;
      canvas.drawPath(
        Path()
          ..moveTo(water.left + 6, y)
          ..quadraticBezierTo(
            water.center.dx,
            y + math.sin(phase + 0.8) * 4,
            water.right - 6,
            y + math.cos(phase) * 2,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFFFFE8B0)
              .withValues(alpha: reflectStrength * (0.5 + i * 0.1)),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          water.left + water.width * 0.22 + math.sin(tMs * 0.005) * 4,
          water.top + water.height * 0.35,
        ),
        width: water.width * 0.18,
        height: water.height * 0.22,
      ),
      Paint()
        ..color = const Color(0xFFFFD080).withValues(alpha: reflectStrength),
    );

    canvas.drawLine(
      Offset(water.left + water.width * 0.15, water.center.dy),
      Offset(water.right - water.width * 0.1, water.center.dy + wave),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(water.left, water.center.dy),
          Offset(water.right, water.center.dy),
          [
            Colors.transparent,
            const Color(0xFFB8E0FF).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          const [0.0, 0.5, 1.0],
        )
        ..strokeWidth = 1.2,
    );

    canvas.restore();

    canvas.drawOval(
      water,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF90B8D0).withValues(alpha: 0.35),
    );
  }

  void _drawRipples(Canvas canvas) {
    for (final ripple in ripples) {
      final age = tMs - ripple.startMs;
      if (age < 0) continue;
      final center = layout.waterPointFromNorm(ripple.normCenter);
      final maxR = layout.waterRect.width * 0.42;
      for (var ring = 0; ring < 3; ring++) {
        final progress = (age - ring * 180) / 1400;
        if (progress < 0 || progress > 1) continue;
        final radius = maxR * progress;
        final alpha = (1 - progress) * 0.45;
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: radius * 2.1,
            height: radius * 0.85,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 - progress * 0.8
            ..color = const Color(0xFFC8E8FF).withValues(alpha: alpha),
        );
      }
    }
  }

  void _drawSymbols(Canvas canvas) {
    if (tMs < _T.symbolsStart) return;

    for (final placement in layout.symbols) {
      final localT = (tMs - _T.symbolsStart - placement.emergeDelayMs) / 1200;
      if (localT <= 0) continue;
      final eased = Curves.easeOutCubic.transform(localT.clamp(0.0, 1.0));
      final alpha = (math.sin(eased * math.pi * 0.9) * 0.75 + 0.15)
          .clamp(0.0, 0.88);
      final scale = 0.55 + eased * 0.45 * placement.scale;
      final center = layout.waterPointFromNorm(placement.normCenter);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(placement.rotation);
      canvas.scale(scale);

      final blurAmount = (1 - eased) * 6;
      if (blurAmount > 0.5) {
        _WaterSymbolArt.draw(
          canvas,
          placement.symbol,
          Offset.zero,
          alpha * 0.35,
          blur: blurAmount,
        );
      }
      _WaterSymbolArt.draw(
        canvas,
        placement.symbol,
        Offset.zero,
        alpha,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WaterSurfacePainter oldDelegate) =>
      oldDelegate.tMs != tMs || oldDelegate.ripples.length != ripples.length;
}

// ─── Yaşlı pirinç fal kasesi (bakla sahnesi paleti) ─────────────────────────

abstract final class _MysticScryingBowlArt {
  static Rect _expand(Rect r, double dx, double dy) => Rect.fromLTRB(
        r.left - dx,
        r.top - dy,
        r.right + dx,
        r.bottom + dy,
      );

  static void drawBody(
    Canvas canvas, {
    required Rect bowlRect,
    required Rect waterRect,
    required double tMs,
  }) {
    final r = bowlRect;
    final w = r.width;
    final h = r.height;
    final cx = r.center.dx;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, r.bottom - h * 0.01),
        width: w * 0.88,
        height: h * 0.11,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    final outer = _outerBowlPath(r);
    final opening = Path()..addOval(_expand(waterRect, w * 0.04, h * 0.06));

    final shell = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(outer, Offset.zero)
      ..addPath(opening, Offset.zero);

    canvas.drawPath(
      shell,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFF9A7048),
            Color(0xFF6E4A2C),
            Color(0xFF4A3018),
            Color(0xFF2A180C),
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(r),
    );

    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF2A180C).withValues(alpha: 0.55),
    );

    final innerWall = Path()
      ..addOval(_expand(waterRect, w * 0.03, h * 0.05));
    canvas.drawPath(
      innerWall,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1008).withValues(alpha: 0.85),
            const Color(0xFF0A0604).withValues(alpha: 0.95),
          ],
        ).createShader(waterRect.inflate(8)),
    );

    final engrave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.14);
    for (var i = 0; i < 3; i++) {
      final inset = w * (0.14 + i * 0.07);
      canvas.drawPath(
        Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(cx, r.top + h * 0.52),
              width: w - inset * 2,
              height: h * (0.42 - i * 0.06),
            ),
          ),
        engrave,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, r.bottom - h * 0.04),
        width: w * 0.22,
        height: h * 0.05,
      ),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF5C3D22), Color(0xFF2A180C)],
        ).createShader(Rect.fromCenter(
          center: Offset(cx, r.bottom - h * 0.04),
          width: w * 0.22,
          height: h * 0.05,
        )),
    );
  }

  static void drawRim(
    Canvas canvas, {
    required Rect bowlRect,
    required Rect waterRect,
    required Offset candleCenter,
    required double tMs,
  }) {
    final w = bowlRect.width;
    final h = bowlRect.height;
    final rimRect = _expand(waterRect, w * 0.07, h * 0.14);
    final flicker = math.sin(tMs * 0.01) * 0.04 + 1.0;

    canvas.drawOval(
      rimRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: math.pi * 0.75,
          endAngle: math.pi * 2.35,
          colors: const [
            Color(0xFF3E2814),
            Color(0xFF8B6538),
            Color(0xFFD4AF37),
            Color(0xFFFFE8B8),
            Color(0xFF8B6538),
            Color(0xFF3E2814),
          ],
          stops: const [0.0, 0.22, 0.42, 0.52, 0.72, 1.0],
        ).createShader(rimRect),
    );

    canvas.drawOval(
      _expand(waterRect, w * 0.02, h * 0.04),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFE8B8).withValues(alpha: 0.22 * flicker),
    );

    final highlight = Path()
      ..addArc(
        Rect.fromCenter(
          center: rimRect.center,
          width: rimRect.width * 0.92,
          height: rimRect.height * 0.55,
        ),
        math.pi * 1.05,
        math.pi * 0.45,
      );
    canvas.drawPath(
      highlight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFE4B5).withValues(alpha: 0.35 * flicker),
    );

    final candleGlow = (candleCenter - rimRect.center).distance;
    final glowAlpha = (1 - (candleGlow / (w * 2.2)).clamp(0.0, 1.0)) * 0.18;
    if (glowAlpha > 0.02) {
      canvas.drawOval(
        rimRect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              ((candleCenter.dx - rimRect.center.dx) / rimRect.width)
                  .clamp(-1.0, 1.0),
              -0.35,
            ),
            radius: 0.85,
            colors: [
              const Color(0xFFFFD89A).withValues(alpha: glowAlpha * flicker),
              Colors.transparent,
            ],
          ).createShader(rimRect),
      );
    }
  }

  static Path _outerBowlPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final cx = r.center.dx;
    return Path()
      ..moveTo(r.left + w * 0.10, r.top + h * 0.30)
      ..cubicTo(
        r.left + w * 0.02,
        r.top + h * 0.52,
        r.left + w * 0.10,
        r.bottom - h * 0.06,
        cx,
        r.bottom - h * 0.01,
      )
      ..cubicTo(
        r.right - w * 0.10,
        r.bottom - h * 0.06,
        r.right - w * 0.02,
        r.top + h * 0.52,
        r.right - w * 0.10,
        r.top + h * 0.30,
      )
      ..quadraticBezierTo(cx, r.top + h * 0.18, r.left + w * 0.10, r.top + h * 0.30)
      ..close();
  }
}

abstract final class _WaterSymbolArt {
  static void draw(
    Canvas canvas,
    _WaterSymbol symbol,
    Offset center,
    double alpha, {
    double blur = 0,
  }) {
    if (alpha <= 0.01) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    for (var i = 3; i >= 1; i--) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + i * 0.35
        ..color = const Color(0xFFE8C878).withValues(alpha: alpha * 0.07 * i)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          blur + 2.0 + i * 2.0,
        );
      _stroke(canvas, symbol, glow);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFD4AF37).withValues(alpha: alpha * 0.82);

    _stroke(canvas, symbol, stroke);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFE8B8).withValues(alpha: alpha * 0.22);
    if (symbol == _WaterSymbol.kalp ||
        symbol == _WaterSymbol.yildiz ||
        symbol == _WaterSymbol.ay) {
      canvas.drawPath(_pathFor(symbol), fill);
    }

    canvas.restore();
  }

  static void _stroke(Canvas canvas, _WaterSymbol s, Paint paint) {
    canvas.drawPath(_pathFor(s), paint);
  }

  static Path _pathFor(_WaterSymbol s) {
    switch (s) {
      case _WaterSymbol.kalp:
        return Path()
          ..moveTo(0, 4)
          ..cubicTo(-8, -4, -12, 4, 0, 12)
          ..cubicTo(12, 4, 8, -4, 0, 4);
      case _WaterSymbol.kus:
        return Path()
          ..moveTo(-12, 2)
          ..quadraticBezierTo(-4, -8, 8, -2)
          ..quadraticBezierTo(12, 0, 6, 4)
          ..moveTo(-6, 0)
          ..quadraticBezierTo(-2, 4, 2, 2);
      case _WaterSymbol.anahtar:
        return Path()
          ..addOval(Rect.fromCenter(center: const Offset(-5, -4), width: 8, height: 8))
          ..moveTo(-1, -1)
          ..lineTo(10, 8)
          ..moveTo(7, 5)
          ..lineTo(12, 5)
          ..moveTo(9, 8)
          ..lineTo(9, 2);
      case _WaterSymbol.yol:
        return Path()
          ..moveTo(-10, 6)
          ..quadraticBezierTo(-2, -2, 8, -6)
          ..quadraticBezierTo(12, -8, 14, -4);
      case _WaterSymbol.ay:
        return Path()
          ..addArc(
            const Rect.fromLTWH(-9, -9, 18, 18),
            math.pi * 0.35,
            math.pi * 1.35,
          );
      case _WaterSymbol.yildiz:
        return _starPath(8, 4);
      case _WaterSymbol.balik:
        return Path()
          ..moveTo(-12, 0)
          ..quadraticBezierTo(-4, -7, 8, -2)
          ..quadraticBezierTo(14, 0, 8, 2)
          ..quadraticBezierTo(-4, 7, -12, 0)
          ..moveTo(10, -2)
          ..lineTo(14, 0)
          ..lineTo(10, 2);
      case _WaterSymbol.goz:
        return Path()
          ..addOval(const Rect.fromLTWH(-11, -5, 22, 10))
          ..addOval(const Rect.fromLTWH(-3.5, -3, 7, 6));
      case _WaterSymbol.halka:
        return Path()
          ..addOval(Rect.fromCenter(center: Offset.zero, width: 14, height: 9));
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
