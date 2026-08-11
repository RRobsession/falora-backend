/// Serdar / Hatice manuel durum (admin override).
enum ManualReaderStatus {
  /// Saat + kota kurallarına göre otomatik.
  auto,

  /// Molada — yeni talep alınmaz.
  onBreak,

  /// Fal bakıyor — meşgul, yeni talep alınmaz.
  reading,

  /// Mesai saati dışında — yeni talep alınmaz.
  outsideHours,

  /// Günlük fal limiti doldu — yeni talep alınmaz.
  quotaFull,
}

extension ManualReaderStatusX on ManualReaderStatus {
  String get code {
    switch (this) {
      case ManualReaderStatus.auto:
        return 'auto';
      case ManualReaderStatus.onBreak:
        return 'molada';
      case ManualReaderStatus.reading:
        return 'fal_bakiyor';
      case ManualReaderStatus.outsideHours:
        return 'mesai_saati_disinda';
      case ManualReaderStatus.quotaFull:
        return 'gunluk_fal_limiti_doldu';
    }
  }

  String get label {
    switch (this) {
      case ManualReaderStatus.auto:
        return 'Otomatik (saat & kota)';
      case ManualReaderStatus.onBreak:
        return 'Molada';
      case ManualReaderStatus.reading:
        return 'Fal bakıyor';
      case ManualReaderStatus.outsideHours:
        return 'Mesai saati dışında';
      case ManualReaderStatus.quotaFull:
        return 'Günlük fal limiti doldu';
    }
  }

  /// Admin override ile yeni talep kabul ediliyor mu?
  bool get acceptsNewRequests => this == ManualReaderStatus.auto;

  String blockedMessage(String readerName) {
    switch (this) {
      case ManualReaderStatus.auto:
        return '$readerName şu an müsait değil.';
      case ManualReaderStatus.onBreak:
        return '$readerName şu an molada. Lütfen daha sonra tekrar deneyin.';
      case ManualReaderStatus.reading:
        return '$readerName şu an fal bakıyor. Lütfen daha sonra tekrar deneyin.';
      case ManualReaderStatus.outsideHours:
        return '$readerName mesai saati dışında. Lütfen aktif saatlerde tekrar deneyin.';
      case ManualReaderStatus.quotaFull:
        return '$readerName bugünkü fal limitini doldurdu. Yarın tekrar açılacak.';
    }
  }

  static ManualReaderStatus fromCode(String? raw) {
    switch (raw?.trim()) {
      case 'molada':
        return ManualReaderStatus.onBreak;
      case 'fal_bakiyor':
        return ManualReaderStatus.reading;
      case 'mesai_saati_disinda':
        return ManualReaderStatus.outsideHours;
      case 'gunluk_fal_limiti_doldu':
        return ManualReaderStatus.quotaFull;
      case 'auto':
      case null:
      case '':
      default:
        return ManualReaderStatus.auto;
    }
  }
}

/// Admin'in seçebileceği tüm durumlar.
const manualReaderStatusOptions = ManualReaderStatus.values;
