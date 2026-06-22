import 'dart:async';

import 'package:falora/models/fortune_models.dart';
import 'package:falora/services/reading_ready_logger.dart';
import 'package:falora/widgets/falora_component_library.dart';
import 'package:flutter/material.dart';

/// Fallarım / Çift Uyumu listesi — hazırlık sayacı ile kayıt kartı.
class ReadingRecordCard extends StatefulWidget {
  const ReadingRecordCard({
    super.key,
    required this.reading,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final FortuneReading reading;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  State<ReadingRecordCard> createState() => _ReadingRecordCardState();
}

class _ReadingRecordCardState extends State<ReadingRecordCard> {
  Timer? _tickTimer;

  FortuneReading get _reading => widget.reading;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(ReadingRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    final needsTick = _reading.showsCountdown;
    if (needsTick && _tickTimer == null) {
      ReadingReadyLogger.countdownStart(_reading.id);
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final remaining = _reading.remainingUntilReady;
        ReadingReadyLogger.countdownTick(_reading.id, remaining);
        if (!_reading.showsCountdown) {
          ReadingReadyLogger.countdownDone(_reading.id);
          _tickTimer?.cancel();
          _tickTimer = null;
        }
        setState(() {});
      });
    } else if (!needsTick) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  }

  FaloraReadingStatus get _status {
    if (_reading.isReadyDisplay) return FaloraReadingStatus.ready;
    if (_reading.isManualPremium) return FaloraReadingStatus.pending;
    return FaloraReadingStatus.preparing;
  }

  String get _statusLabel => _reading.statusBadgeLabel;

  @override
  Widget build(BuildContext context) {
    return FaloraRecordCard(
      leading: widget.leading,
      title: widget.title,
      subtitle: widget.subtitle,
      status: _status,
      statusLabel: _statusLabel,
      onTap: widget.onTap,
    );
  }
}
