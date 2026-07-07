/// Bildirime tıklanınca uygulama içi yönlendirme hedefi.
class NotificationOpenRequest {
  const NotificationOpenRequest({
    required this.type,
    this.readingId,
  });

  final String type;
  final String? readingId;

  /// Ana shell sekmesi: 1 = Fallarım, 3 = Çift Uyumu.
  int? get targetTabIndex {
    switch (type) {
      case 'couple':
        return 3;
      case 'fortune':
      case 'manual':
        return 1;
      default:
        return null;
    }
  }

  factory NotificationOpenRequest.fromData(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim() ?? '';
    final readingId = data['readingId']?.toString().trim();
    final requestId = data['requestId']?.toString().trim();
    final id = (readingId != null && readingId.isNotEmpty)
        ? readingId
        : ((requestId != null && requestId.isNotEmpty) ? requestId : null);
    return NotificationOpenRequest(
      type: type,
      readingId: id,
    );
  }

  bool get isValid =>
      type == 'fortune' ||
      type == 'couple' ||
      type == 'manual' ||
      type == 'admin_manual_request';
}
