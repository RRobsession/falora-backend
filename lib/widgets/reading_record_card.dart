import 'package:falora/models/fortune_models.dart';
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
  FortuneReading get _reading => widget.reading;

  FaloraReadingStatus get _status {
    if (_reading.isReadyDisplay) return FaloraReadingStatus.ready;
    if (_reading.isFailedDisplay) return FaloraReadingStatus.error;
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
