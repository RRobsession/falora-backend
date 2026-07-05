import 'package:falora/ai_service.dart';
import 'package:falora/config/app_branding.dart';
import 'package:falora/config/app_links_config.dart';
import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

enum FortuneShareOutcome {
  shared,
  clipboard,
  dismissed,
  failed,
}

/// Fal, çift uyumu ve otomatik kategori sonuçlarını sistem paylaşım menüsüyle paylaşır.
class FortuneShareService {
  FortuneShareService._();

  static final FortuneShareService instance = FortuneShareService._();

  bool canShare(FortuneReading reading) =>
      reading.isReadyDisplay &&
      reading.hasResult &&
      !isFortuneResultError(reading.trimmedResult);

  String shareTitle(FortuneReading reading) {
    switch (reading.category) {
      case FortuneCategory.ciftUyumu:
        return 'Çift Uyum Raporum';
      case FortuneCategory.iliskiTavsiyesi:
        return 'İlişki Analizim';
      case FortuneCategory.ruyaTabiri:
        return 'Rüya Tabirim';
      case FortuneCategory.numeroloji:
        return 'Numeroloji Yorumum';
      case FortuneCategory.burcYorumu:
        return 'Burç Yorumum';
      default:
        return '${reading.category.label} — Fal Yorumum';
    }
  }

  String buildShareText(FortuneReading reading) {
    final buffer = StringBuffer();
    final headline = isAutoOnlyCategory(reading.category)
        ? reading.category.resultScreenTitle
        : reading.category == FortuneCategory.ciftUyumu
            ? 'Çift Uyumu Raporu'
            : reading.category.label;

    buffer.writeln('$headline — $appDisplayName');
    buffer.writeln();

    final summary = reading.summary.trim();
    if (summary.isNotEmpty) {
      buffer.writeln(summary);
      buffer.writeln();
    }

    final result = reading.trimmedResult;
    if (reading.category == FortuneCategory.ciftUyumu) {
      final percent = parseCompatibilityPercent(result);
      if (percent != null) {
        buffer.writeln('Uyumluluk: %$percent');
        buffer.writeln();
      }
      buffer.writeln(stripCompatibilityHeader(result));
    } else {
      buffer.writeln(result);
    }

    buffer.writeln();
    buffer.writeln('—');
    buffer.writeln('$appDisplayName ile fal baktım.');
    if (playStoreUrl.trim().isNotEmpty) {
      buffer.writeln(playStoreUrl.trim());
    }

    return buffer.toString().trim();
  }

  Future<FortuneShareOutcome> shareFortuneReading(
    FortuneReading reading, {
    BuildContext? context,
    Rect? sharePositionOrigin,
  }) async {
    if (!canShare(reading)) return FortuneShareOutcome.failed;

    final text = buildShareText(reading);
    final subject = shareTitle(reading);
    final origin = sharePositionOrigin ?? _shareOriginFromContext(context);

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          title: subject,
          sharePositionOrigin: origin,
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        return FortuneShareOutcome.dismissed;
      }

      if (result.status == ShareResultStatus.success) {
        return FortuneShareOutcome.shared;
      }

      if (kIsWeb) {
        return FortuneShareOutcome.shared;
      }

      return _clipboardFallback(text);
    } catch (e, stack) {
      debugPrint('FORTUNE_SHARE_ERROR: $e');
      debugPrint(stack.toString());
      return _clipboardFallback(text);
    }
  }

  Rect? _shareOriginFromContext(BuildContext? context) {
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  Future<FortuneShareOutcome> _clipboardFallback(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return FortuneShareOutcome.clipboard;
    } catch (e) {
      debugPrint('FORTUNE_SHARE_CLIPBOARD_ERROR: $e');
      return FortuneShareOutcome.failed;
    }
  }
}
