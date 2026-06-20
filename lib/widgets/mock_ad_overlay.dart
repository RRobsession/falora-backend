import 'dart:async';

import 'package:falora/services/ads/ad_config.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';

/// Sahte tam ekran reklam. AdMob Rewarded/Interstitial için yer tutucu.
class MockAdOverlay extends StatefulWidget {
  const MockAdOverlay({
    super.key,
    required this.title,
    required this.message,
    this.closableAfterComplete = false,
  });

  final String title;
  final String message;

  /// true: süre dolunca kullanıcı kapatır (interstitial).
  /// false: süre dolunca otomatik tamamlanır (rewarded).
  final bool closableAfterComplete;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    bool closableAfterComplete = false,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MockAdOverlay(
          title: title,
          message: message,
          closableAfterComplete: closableAfterComplete,
        ),
      ),
    ).then((value) => value ?? false);
  }

  @override
  State<MockAdOverlay> createState() => _MockAdOverlayState();
}

class _MockAdOverlayState extends State<MockAdOverlay> {
  late int _secondsLeft;
  Timer? _timer;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = mockAdDisplayDuration.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _secondsLeft = 0;
          _complete = true;
        });
        if (!widget.closableAfterComplete) {
          Navigator.of(context).pop(true);
        }
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: faloraBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: widget.closableAfterComplete && _complete
                    ? IconButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.close, color: faloraTextPrimary),
                      )
                    : const SizedBox(width: 48, height: 48),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: faloraCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: faloraAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_outline,
                        size: 64, color: faloraGold),
                    const SizedBox(height: 20),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: faloraTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: faloraTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const CircularProgressIndicator(color: faloraGold),
                    const SizedBox(height: 16),
                    Text(
                      _complete
                          ? 'Reklam tamamlandı'
                          : 'Yükleniyor... $_secondsLeft sn',
                      style: const TextStyle(
                        color: faloraTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (widget.closableAfterComplete && _complete)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Kapat'),
                  ),
                )
              else
                const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
