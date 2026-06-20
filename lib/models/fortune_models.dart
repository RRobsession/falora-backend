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
    Color(0xFFA78BFA),
  ),
  bakla(
    'Bakla Falı',
    'Baklaların kadim mesajlarını çöz',
    'assets/icons/bakla.svg',
    FontAwesomeIcons.seedling,
    Color(0xFF81C784),
  ),
  kahve(
    'Kahve Falı',
    'Fincanındaki sembollerin anlamını öğren',
    'assets/icons/kahve.svg',
    FontAwesomeIcons.mugHot,
    Color(0xFFBCAAA4),
  ),
  su(
    'Su Falı',
    'Su enerjisinin mesajlarını keşfet',
    'assets/icons/su.svg',
    FontAwesomeIcons.droplet,
    Color(0xFF64B5F6),
  ),
  iskambil(
    'İskambil Falı',
    'Kartların keskin yorumuyla yolunu bul',
    'assets/icons/iskambil.svg',
    FontAwesomeIcons.gem,
    Color(0xFFB76E79),
  ),
  ciftUyumu(
    'Çift Uyumu',
    'İlişkinizin uyumunu derinlemesine keşfet',
    'assets/icons/cift.svg',
    FontAwesomeIcons.solidHeart,
    Color(0xFFE879A8),
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
    this.availableAt,
    this.firestoreStatus = 'pending',
    this.usesDelayGate = false,
    this.isManualPremium = false,
    this.manualReaderName,
  });

  final String id;
  final FortuneCategory category;
  FortuneStatus status;
  final DateTime createdAt;
  final String summary;
  String result;
  final DateTime? availableAt;
  final String firestoreStatus;
  /// Eski kayıtlarda availableAt alanı vardı; artık sonuç hazır olunca gösterilir.
  final bool usesDelayGate;
  /// Gerçek falcı (Serdar/Hatice) manuel premium talep.
  final bool isManualPremium;
  final String? manualReaderName;

  String get trimmedResult => result.trim();

  bool get hasResult => trimmedResult.isNotEmpty;

  /// Eski kayıt: availableAt yok veya status alanı yokken oluşturulmuş.
  bool get isLegacyRecord => !usesDelayGate;

  bool get isReadyDisplay {
    if (isManualPremium) {
      return firestoreStatus == 'answered' && hasResult;
    }
    if (firestoreStatus == 'ready') return true;
    if (hasResult) return true;
    return false;
  }

  bool get isPreparingDisplay {
    if (isManualPremium) {
      return !isReadyDisplay;
    }
    if (isReadyDisplay) return false;
    return firestoreStatus == 'pending' || !hasResult;
  }

  bool get isViewable => isReadyDisplay;

  FortuneStatus get displayStatus =>
      isReadyDisplay ? FortuneStatus.hazir : FortuneStatus.hazirlaniyor;

  FortuneReading copyWith({
    FortuneStatus? status,
    String? result,
    DateTime? availableAt,
    String? firestoreStatus,
    bool? usesDelayGate,
    bool? isManualPremium,
    String? manualReaderName,
  }) {
    return FortuneReading(
      id: id,
      category: category,
      status: status ?? this.status,
      createdAt: createdAt,
      summary: summary,
      result: result ?? this.result,
      availableAt: availableAt ?? this.availableAt,
      firestoreStatus: firestoreStatus ?? this.firestoreStatus,
      usesDelayGate: usesDelayGate ?? this.usesDelayGate,
      isManualPremium: isManualPremium ?? this.isManualPremium,
      manualReaderName: manualReaderName ?? this.manualReaderName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'summary': summary,
        'result': result,
        'availableAt': availableAt?.toIso8601String(),
        'firestoreStatus': firestoreStatus,
        'usesDelayGate': usesDelayGate,
        'isManualPremium': isManualPremium,
        'manualReaderName': manualReaderName,
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
      availableAt: json['availableAt'] != null
          ? DateTime.parse(json['availableAt'] as String)
          : null,
      firestoreStatus: json['firestoreStatus'] as String? ?? 'pending',
      usesDelayGate: json['usesDelayGate'] as bool? ?? false,
      isManualPremium: json['isManualPremium'] as bool? ?? false,
      manualReaderName: json['manualReaderName'] as String?,
    );
  }
}
