import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/config/manual_fortune_config.dart';
import 'package:flutter/foundation.dart';

class ManualReaderDailyQuota {
  const ManualReaderDailyQuota({
    this.serdar = 0,
    this.hatice = 0,
  });

  static const empty = ManualReaderDailyQuota();

  final int serdar;
  final int hatice;

  int countFor(String readerId) =>
      readerId == 'hatice' ? hatice : serdar;

  int get total => serdar + hatice;
}

class ManualReaderQuotaService {
  ManualReaderQuotaService._();

  static final ManualReaderQuotaService instance = ManualReaderQuotaService._();

  static const _collection = 'manual_reader_daily_quota';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Kota günü 10:30'da sıfırlanır (aktif saat başlangıcı).
  String quotaDayKey([DateTime? moment]) {
    final now = moment ?? DateTime.now();
    final minuteOfDay = now.hour * 60 + now.minute;
    final date = minuteOfDay < manualReaderActiveStartMinute
        ? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1))
        : DateTime(now.year, now.month, now.day);
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  ManualReaderDailyQuota _fromData(Map<String, dynamic>? data) {
    if (data == null) return ManualReaderDailyQuota.empty;
    return ManualReaderDailyQuota(
      serdar: (data['serdar'] as num?)?.toInt() ?? 0,
      hatice: (data['hatice'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ManualReaderDailyQuota> fetchToday() async {
    try {
      final snap =
          await _db.collection(_collection).doc(quotaDayKey()).get();
      return _fromData(snap.data());
    } catch (e) {
      debugPrint('MANUAL READER QUOTA FETCH ERROR: $e');
      return ManualReaderDailyQuota.empty;
    }
  }

  Stream<ManualReaderDailyQuota> watchToday() => watchDay(quotaDayKey());

  Stream<ManualReaderDailyQuota> watchDay(String dayKey) {
    return _db
        .collection(_collection)
        .doc(dayKey)
        .snapshots()
        .map((snap) => _fromData(snap.data()));
  }

  /// Atomik kota artırımı; doluysa false döner.
  Future<bool> tryIncrementInTransaction({
    required Transaction tx,
    required String readerId,
    required String dayKey,
  }) async {
    if (readerId != 'serdar' && readerId != 'hatice') return false;

    final ref = _db.collection(_collection).doc(dayKey);
    final snap = await tx.get(ref);
    final data = snap.data();
    final serdar = (data?['serdar'] as num?)?.toInt() ?? 0;
    final hatice = (data?['hatice'] as num?)?.toInt() ?? 0;
    final current = readerId == 'hatice' ? hatice : serdar;
    if (current >= manualReaderDailyQuotaCloseAt) return false;

    tx.set(
      ref,
      {
        'serdar': readerId == 'serdar' ? serdar + 1 : serdar,
        'hatice': readerId == 'hatice' ? hatice + 1 : hatice,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return true;
  }
}
