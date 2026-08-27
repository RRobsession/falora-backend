import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/services/daily_horoscope_service.dart';

class DailyAngelCardData {
  const DailyAngelCardData({
    required this.title,
    required this.text,
    required this.dateKey,
    required this.expiresAt,
  });

  final String title;
  final String text;
  final String dateKey;
  final DateTime expiresAt;

  factory DailyAngelCardData.fromMap(Map<String, dynamic> data) {
    final expires = data['expiresAt'];
    return DailyAngelCardData(
      title: data['title']?.toString().trim() ?? '',
      text: data['text']?.toString().trim() ?? '',
      dateKey: data['dateKey']?.toString().trim() ?? '',
      expiresAt: expires is Timestamp
          ? expires.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get isValid =>
      title.isNotEmpty &&
      text.isNotEmpty &&
      dateKey == DailyHoroscopeService.istanbulDateKey() &&
      DateTime.now().isBefore(expiresAt);
}

class DailyAngelCardService {
  DailyAngelCardService._();

  static final DailyAngelCardService instance = DailyAngelCardService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<DailyAngelCardData?> watchToday(String userId) {
    final dateKey = DailyHoroscopeService.istanbulDateKey();
    return _db
        .collection('users')
        .doc(userId)
        .collection('daily_angel_cards')
        .doc(dateKey)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      final card = DailyAngelCardData.fromMap(data);
      return card.isValid ? card : null;
    });
  }
}
