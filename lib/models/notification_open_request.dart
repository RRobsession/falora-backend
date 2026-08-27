/// Bildirime tıklanınca uygulama içi yönlendirme hedefi.
class NotificationOpenRequest {
  const NotificationOpenRequest({
    required this.type,
    this.readingId,
    this.date,
    this.zodiac,
    this.title,
    this.body,
  });

  final String type;
  final String? readingId;
  final String? date;
  final String? zodiac;
  final String? title;
  final String? body;

  /// Ana shell sekmesi: 1 = Fallarım, 3 = Çift Uyumu.
  int? get targetTabIndex {
    switch (type) {
      case 'couple':
        return 3;
      case 'fortune':
      case 'manual':
        return 1;
      case 'daily_horoscope':
      case 'angel_card':
        return 0;
      default:
        return null;
    }
  }

  factory NotificationOpenRequest.fromData(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim() ?? '';
    final readingId = data['readingId']?.toString().trim();
    final requestId = data['requestId']?.toString().trim();
    final date = data['date']?.toString().trim();
    final zodiac = data['zodiac']?.toString().trim();
    final title = data['title']?.toString().trim();
    final body = data['body']?.toString().trim();
    final id = (readingId != null && readingId.isNotEmpty)
        ? readingId
        : ((requestId != null && requestId.isNotEmpty) ? requestId : null);
    return NotificationOpenRequest(
      type: type,
      readingId: id,
      date: (date != null && date.isNotEmpty) ? date : null,
      zodiac: (zodiac != null && zodiac.isNotEmpty) ? zodiac : null,
      title: (title != null && title.isNotEmpty) ? title : null,
      body: (body != null && body.isNotEmpty) ? body : null,
    );
  }

  bool get isValid =>
      type == 'fortune' ||
      type == 'couple' ||
      type == 'manual' ||
      type == 'admin_manual_request' ||
      type == 'daily_horoscope' ||
      type == 'angel_card' ||
      type == 'admin_broadcast';
}
