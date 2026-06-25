import 'package:falora/ai_service.dart';
import 'package:falora/config/reading_delay_config.dart';
import 'package:falora/models/tarot_card.dart';
import 'package:falora/utils/ai_result_sanitize.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const burclar = [
  'Koç', 'Boğa', 'İkizler', 'Yengeç', 'Aslan', 'Başak',
  'Terazi', 'Akrep', 'Yay', 'Oğlak', 'Kova', 'Balık',
];

enum FortuneCategory {
  tarot(
    'Tarot Falı',
    'Kartların rehberliğinde enerjini keşfet',
    'assets/icons/tarot.svg',
    FontAwesomeIcons.solidClone,
    Color(0xFF6B4F2A),
  ),
  bakla(
    'Bakla Falı',
    'Baklaların kadim mesajlarını çöz',
    'assets/icons/bakla.svg',
    FontAwesomeIcons.seedling,
    Color(0xFF5C7A4E),
  ),
  kahve(
    'Kahve Falı',
    'Fincanındaki sembollerin anlamını öğren',
    'assets/icons/kahve.svg',
    FontAwesomeIcons.mugHot,
    Color(0xFF8B6A3E),
  ),
  su(
    'Su Falı',
    'Su enerjisinin mesajlarını keşfet',
    'assets/icons/su.svg',
    FontAwesomeIcons.droplet,
    Color(0xFF4A6B7A),
  ),
  iskambil(
    'İskambil Falı',
    'Kartların keskin yorumuyla yolunu bul',
    'assets/icons/iskambil.svg',
    FontAwesomeIcons.gem,
    Color(0xFF7A4A52),
  ),
  ciftUyumu(
    'Çift Uyumu',
    'İlişkinizin uyumunu derinlemesine keşfet',
    'assets/icons/cift.svg',
    FontAwesomeIcons.solidHeart,
    Color(0xFF8B4A5C),
  ),
  ruyaTabiri(
    'Rüya Tabiri',
    'Rüyalarının sembolik mesajını keşfet',
    'assets/icons/ruya.svg',
    FontAwesomeIcons.cloudMoon,
    Color(0xFF5C4A6E),
  ),
  numeroloji(
    'Numeroloji',
    'İsmin ve doğum tarihinle enerjini çöz',
    'assets/icons/numeroloji.svg',
    FontAwesomeIcons.hashtag,
    Color(0xFFB8860B),
  ),
  burcYorumu(
    'Burç Yorumu',
    'Güneş ve ay burcunla kişisel rehberlik al',
    'assets/icons/burc.svg',
    FontAwesomeIcons.star,
    Color(0xFF7A5C3E),
  ),
  iliskiTavsiyesi(
    'İlişki Tavsiyesi',
    'İlişkinizdeki sorunlara objektif ve dengeli bakış',
    'assets/icons/iliski.svg',
    FontAwesomeIcons.comments,
    Color(0xFF8B4A62),
  );

  const FortuneCategory(
    this.label,
    this.description,
    this.iconPath,
    this.fallbackIcon,
    this.color,
  );
  final String label;
  final String description;
  final String iconPath;
  final FaIconData fallbackIcon;
  final Color color;

  bool get hasGradientIcon => this == FortuneCategory.ciftUyumu;

  /// Bekleme ekranlarında gösterilen kısa metin (tek cümle).
  String get waitingMessage {
    switch (this) {
      case FortuneCategory.tarot:
        return 'Kartların mesajları yorumlanıyor...';
      case FortuneCategory.bakla:
        return 'Baklaların işaretleri inceleniyor...';
      case FortuneCategory.kahve:
        return 'Falın özenle hazırlanıyor...';
      case FortuneCategory.su:
        return 'Suyun yansıttığı işaretler değerlendiriliyor...';
      case FortuneCategory.iskambil:
        return 'Kartların anlattıkları yorumlanıyor...';
      case FortuneCategory.ciftUyumu:
        return 'Uyum raporunuz hazırlanıyor...';
      case FortuneCategory.ruyaTabiri:
        return 'Rüyanız sembolik olarak yorumlanıyor...';
      case FortuneCategory.numeroloji:
        return 'Numeroloji yorumunuz hazırlanıyor...';
      case FortuneCategory.burcYorumu:
        return 'Burç yorumunuz hazırlanıyor...';
      case FortuneCategory.iliskiTavsiyesi:
        return 'İlişki tavsiyeniz hazırlanıyor...';
    }
  }

  /// Sonuç ekranı başlığı (otomatik kategoriler).
  String get resultScreenTitle {
    switch (this) {
      case FortuneCategory.ruyaTabiri:
        return 'Rüya Tabiri';
      case FortuneCategory.numeroloji:
        return 'Numeroloji Yorumu';
      case FortuneCategory.burcYorumu:
        return 'Burç Yorumu';
      case FortuneCategory.iliskiTavsiyesi:
        return 'İlişki Tavsiyesi';
      default:
        return label;
    }
  }
}

enum FortuneStatus { hazirlaniyor, hazir }

class FortuneReading {
  FortuneReading({
    required this.id,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.summary,
    required this.result,
    this.readyAt,
    this.firestoreStatus = 'pending',
    this.usesDelayGate = false,
    this.isManualPremium = false,
    this.manualReaderName,
    this.selectedTarotCards = const [],
  });

  final String id;
  final FortuneCategory category;
  FortuneStatus status;
  final DateTime createdAt;
  final String summary;
  String result;
  final DateTime? readyAt;
  final String firestoreStatus;
  /// Yeni kayıtlarda readyAt ile 3 dk hazırlık kapısı uygulanır.
  final bool usesDelayGate;
  /// Gerçek falcı (Serdar/Hatice) manuel premium talep.
  final bool isManualPremium;
  final String? manualReaderName;
  /// AI tarot falında seçilen 8 kart.
  final List<TarotCardSelection> selectedTarotCards;

  String get trimmedResult => sanitizeAiResult(result);

  bool get hasResult => trimmedResult.isNotEmpty;

  /// Eski kayıt: readyAt yok — sonuç gelince hemen gösterilir.
  bool get isLegacyRecord => readyAt == null && !usesDelayGate;

  bool get isReadyAtElapsed {
    final at = readyAt;
    if (at == null) return true;
    return !DateTime.now().isBefore(at);
  }

  Duration get remainingUntilReady {
    final at = readyAt;
    if (at == null) return Duration.zero;
    final diff = at.difference(DateTime.now());
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  bool get showsCountdown =>
      readyAt != null &&
      !isReadyAtElapsed &&
      !isReadyDisplay &&
      !isFailedDisplay;

  bool get isFailedDisplay =>
      firestoreStatus == 'error' &&
      (!hasResult || isFortuneResultError(trimmedResult));

  String get statusBadgeLabel {
    if (isReadyDisplay) return 'Hazır';
    if (isFailedDisplay) return 'Oluşturulamadı';
    if (isManualPremium && !isReadyAtElapsed && readyAt != null) {
      return 'Beklemede · ${formatReadingCountdown(remainingUntilReady)}';
    }
    if (isManualPremium) return 'Beklemede';
    if (showsCountdown) {
      return 'Hazırlanıyor · ${formatReadingCountdown(remainingUntilReady)}';
    }
    return 'Hazırlanıyor';
  }

  bool get isReadyDisplay {
    if (isManualPremium) {
      if (firestoreStatus != 'answered' || !hasResult) return false;
      return isReadyAtElapsed;
    }
    if (!hasResult) return false;
    if (readyAt == null) {
      return firestoreStatus == 'ready' || hasResult;
    }
    return isReadyAtElapsed && hasResult;
  }

  bool get isPreparingDisplay {
    if (isFailedDisplay) return false;
    if (isManualPremium) {
      return !isReadyDisplay;
    }
    if (isReadyDisplay) return false;
    return firestoreStatus == 'pending' || !hasResult;
  }

  bool get isViewable => isReadyDisplay || isFailedDisplay;

  FortuneStatus get displayStatus =>
      isReadyDisplay ? FortuneStatus.hazir : FortuneStatus.hazirlaniyor;

  FortuneReading copyWith({
    FortuneStatus? status,
    String? result,
    DateTime? readyAt,
    String? firestoreStatus,
    bool? usesDelayGate,
    bool? isManualPremium,
    String? manualReaderName,
    List<TarotCardSelection>? selectedTarotCards,
  }) {
    return FortuneReading(
      id: id,
      category: category,
      status: status ?? this.status,
      createdAt: createdAt,
      summary: summary,
      result: result ?? this.result,
      readyAt: readyAt ?? this.readyAt,
      firestoreStatus: firestoreStatus ?? this.firestoreStatus,
      usesDelayGate: usesDelayGate ?? this.usesDelayGate,
      isManualPremium: isManualPremium ?? this.isManualPremium,
      manualReaderName: manualReaderName ?? this.manualReaderName,
      selectedTarotCards: selectedTarotCards ?? this.selectedTarotCards,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'summary': summary,
        'result': result,
        'readyAt': readyAt?.toIso8601String(),
        'firestoreStatus': firestoreStatus,
        'usesDelayGate': usesDelayGate,
        'isManualPremium': isManualPremium,
        'manualReaderName': manualReaderName,
        if (selectedTarotCards.isNotEmpty)
          'selectedTarotCards':
              selectedTarotCards.map((c) => c.toMap()).toList(),
      };

  factory FortuneReading.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String;
    final category = FortuneCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => FortuneCategory.tarot,
    );
    final statusName = json['status'] as String? ?? 'hazirlaniyor';
    final status = FortuneStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => FortuneStatus.hazirlaniyor,
    );
    return FortuneReading(
      id: json['id'] as String,
      category: category,
      status: status,
      createdAt: DateTime.parse(json['createdAt'] as String),
      summary: json['summary'] as String,
      result: json['result'] as String? ?? '',
      readyAt: _parseReadyAtFromJson(json),
      firestoreStatus: json['firestoreStatus'] as String? ?? 'pending',
      usesDelayGate: json['usesDelayGate'] as bool? ?? false,
      isManualPremium: json['isManualPremium'] as bool? ?? false,
      manualReaderName: json['manualReaderName'] as String?,
      selectedTarotCards: _parseSelectedTarotCards(json),
    );
  }
}

DateTime? _parseReadyAtFromJson(Map<String, dynamic> json) {
  final raw = json['readyAt'] ?? json['availableAt'];
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

List<TarotCardSelection> _parseSelectedTarotCards(Map<String, dynamic> json) {
  final raw = json['selectedTarotCards'] ?? json['selectedCards'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => TarotCardSelection.fromMap(Map<String, dynamic>.from(item)))
      .toList();
}
