import 'dart:math' as math;

import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

const _splashAsset = 'assets/characters/tombik_teyze.png';
const _splashDuration = Duration(milliseconds: 3000);

/// Uygulama açılışında Tombik Teyze karşılama animasyonu.
class AppIntroSplashScreen extends StatefulWidget {
  const AppIntroSplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<AppIntroSplashScreen> createState() => _AppIntroSplashScreenState();
}

class _AppIntroSplashScreenState extends State<AppIntroSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _splashDuration)
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.onFinished();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _at(double t, double start, double end, Curve curve) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return curve.transform((t - start) / (end - start));
  }

  /// Çok yavaş, ağır nefes — neredeyse fark edilmez.
  double _breathe(double t) {
    final appear = _at(t, 0.0, 0.32, Curves.easeInOutCubic);
    if (t >= 0.76) return appear;
    final wave = 0.5 + 0.5 * math.sin(t * math.pi * 1.2);
    final pulse = 0.92 + wave * 0.08;
    return appear * pulse;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final figureHeight = math.min(size.height * 0.48, 340.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final sceneOut = 1 - _at(t, 0.84, 1.0, Curves.easeInOut);
        final figureOpacity = _breathe(t);

        return Opacity(
          opacity: sceneOut,
          child: Scaffold(
            body: FaloraBackground(
              child: SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Opacity(
                        opacity: figureOpacity * 0.85,
                        child: _WelcomeGlow(height: figureHeight),
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: Opacity(
                          opacity: figureOpacity,
                          child: SizedBox(
                            width: figureHeight * 1.12,
                            height: figureHeight,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                _SoftHalo(size: figureHeight * 0.9),
                                _FadedCharacterImage(
                                  asset: _splashAsset,
                                  height: figureHeight,
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _WelcomeGlow extends StatelessWidget {
  const _WelcomeGlow({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: height * 1.05,
        height: height * 1.05,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              faloraGold.withValues(alpha: 0.18),
              faloraBronze.withValues(alpha: 0.06),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

class _SoftHalo extends StatelessWidget {
  const _SoftHalo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: faloraGold.withValues(alpha: 0.2),
          width: 1.2,
        ),
        gradient: RadialGradient(
          colors: [
            faloraParchmentRaised.withValues(alpha: 0.5),
            faloraParchmentRaised.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _FadedCharacterImage extends StatelessWidget {
  const _FadedCharacterImage({
    required this.asset,
    required this.height,
  });

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.58, 0.82, 1.0],
            colors: [
              Colors.white,
              Colors.white,
              Color(0xBFFFFFFF),
              Colors.transparent,
            ],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          asset,
          height: height,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
