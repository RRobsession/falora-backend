import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/config/reading_delay_config.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/models/tarot_card.dart';
import 'package:flutter/foundation.dart';

class FortuneSubmitException implements Exception {
  FortuneSubmitException(this.message);
  final String message;

  @override
  String toString() => message;
}

class FortuneStorageService {
  FortuneStorageService._();

  static final FortuneStorageService instance = FortuneStorageService._();

  static const _fortunes = 'fortune_requests';
  static const _couples = 'couple_compatibility_requests';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String newFortuneId() => _db.collection(_fortunes).doc().id;

  String newCoupleId() => _db.collection(_couples).doc().id;

  Future<List<FortuneReading>> loadFortunes(String userId) async {
    try {
      final snap = await _db
          .collection(_fortunes)
          .where('userId', isEqualTo: userId)
          .get();

      final readings = snap.docs.map(_fortuneFromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return readings;
    } catch (e) {
      debugPrint('FIRESTORE loadFortunes error: $e');
      return [];
    }
  }

  Future<List<FortuneReading>> loadCoupleFortunes(String userId) async {
    try {
      final snap = await _db
          .collection(_couples)
          .where('userId', isEqualTo: userId)
          .get();

      final readings = snap.docs.map(_coupleFromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return readings;
    } catch (e) {
      debugPrint('FIRESTORE loadCoupleFortunes error: $e');
      return [];
    }
  }

  /// Eski kayıtları ready yap: result dolu + readyAt alanı yok.
  Future<void> migrateLegacyRecords(String userId) async {
    try {
      await Future.wait([
        _migrateCollection(_fortunes, userId),
        _migrateCollection(_couples, userId),
      ]);
    } catch (e) {
      debugPrint('FIRESTORE migrateLegacy error: $e');
    }
  }

  Future<void> _migrateCollection(String collection, String userId) async {
    final snap = await _db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in snap.docs) {
      final d = doc.data();
      final result = (d['result'] as String?)?.trim() ?? '';
      if (result.isEmpty) continue;

      final hasReadyAt = (d.containsKey('readyAt') && d['readyAt'] != null) ||
          (d.containsKey('availableAt') && d['availableAt'] != null);
      final rawStatus = d['status'] as String?;

      final needsMigration =
          !hasReadyAt || rawStatus == null || rawStatus.isEmpty;

      if (needsMigration && rawStatus != 'ready') {
        await doc.reference.update({'status': 'ready'});
        debugPrint('MIGRATE legacy $collection/${doc.id} -> ready');
      }
    }
  }

  Future<void> createCategoryFortune({
    required String id,
    required String userId,
    required FortuneCategory category,
    required String title,
    required Map<String, dynamic> inputData,
    required int tokenCost,
    String? tellerId,
    String? tellerName,
    DateTime? createdAt,
    DateTime? readyAt,
  }) async {
    final created = createdAt ?? DateTime.now();
    final ready = readyAt ?? computeReadyAt(created);
    await _db.collection(_fortunes).doc(id).set({
      'userId': userId,
      'category': category.name,
      'title': title,
      'inputData': inputData,
      'result': '',
      'status': 'pending',
      'tokenCost': tokenCost,
      if (tellerId != null) 'tellerId': tellerId,
      if (tellerName != null) 'tellerName': tellerName,
      'createdAt': Timestamp.fromDate(created),
      'readyAt': Timestamp.fromDate(ready),
    });
  }

  Future<void> createFortune({
    required String id,
    required String userId,
    required FortuneCategory category,
    required String name,
    required int age,
    required String zodiac,
    required String intention,
    List<String> imageNames = const [],
    String? tellerId,
    String? tellerName,
    List<TarotCardSelection> selectedTarotCards = const [],
    DateTime? createdAt,
    DateTime? readyAt,
  }) async {
    final created = createdAt ?? DateTime.now();
    final ready = readyAt ?? computeReadyAt(created);
    await _db.collection(_fortunes).doc(id).set({
      'userId': userId,
      'category': category.name,
      'name': name,
      'age': age,
      'zodiac': zodiac,
      'intention': intention,
      if (imageNames.isNotEmpty) 'imageNames': imageNames,
      if (tellerId != null) 'tellerId': tellerId,
      if (tellerName != null) 'tellerName': tellerName,
      if (selectedTarotCards.isNotEmpty)
        'selectedCards': selectedTarotCards.map((c) => c.toMap()).toList(),
      'result': '',
      'status': 'pending',
      'createdAt': Timestamp.fromDate(created),
      'readyAt': Timestamp.fromDate(ready),
    });
  }

  Future<void> deleteFortune(String id) async {
    await _db.collection(_fortunes).doc(id).delete();
  }

  Future<void> deductTokensForExistingFortune({
    required String userId,
    required String fortuneId,
    required int tokenCost,
  }) async {
    try {
      final ok = await _db.runTransaction<bool>((tx) async {
        final userRef = _db.collection('users').doc(userId);
        final fortuneRef = _db.collection(_fortunes).doc(fortuneId);

        final userSnap = await tx.get(userRef);
        final fortuneSnap = await tx.get(fortuneRef);

        if (!fortuneSnap.exists || !userSnap.exists) return false;

        final tokens = (userSnap.data()?['tokens'] as num?)?.toInt() ?? 0;
        if (tokens < tokenCost) return false;

        tx.update(userRef, {'tokens': tokens - tokenCost});
        return true;
      });
      if (!ok) {
        throw FortuneSubmitException('Jeton düşülemedi veya fal isteği bulunamadı.');
      }
    } on FortuneSubmitException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('FORTUNE TOKEN DEDUCT FIREBASE ERROR: ${e.code} ${e.message}');
      throw FortuneSubmitException('Firestore jeton hatası: ${e.code} ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('FORTUNE TOKEN DEDUCT ERROR: $e');
      debugPrint(stackTrace.toString());
      throw FortuneSubmitException('Jeton düşme hatası: $e');
    }
  }

  Future<void> updateFortuneResult(String id, String result) async {
    try {
      await _db.collection(_fortunes).doc(id).update({'result': result});
    } on FirebaseException catch (e) {
      debugPrint('FORTUNE FIRESTORE UPDATE FIREBASE ERROR: ${e.code} ${e.message}');
      throw FortuneSubmitException(
        'Firestore sonuç kaydı hatası: ${e.code} ${e.message}',
      );
    } catch (e, stackTrace) {
      debugPrint('FORTUNE FIRESTORE UPDATE ERROR: $e');
      debugPrint(stackTrace.toString());
      throw FortuneSubmitException('Firestore sonuç kaydı hatası: $e');
    }
  }

  Future<void> markFortuneReady(String id) async {
    await _db.collection(_fortunes).doc(id).update({'status': 'ready'});
  }

  Future<void> markFortuneError(String id) async {
    await _db.collection(_fortunes).doc(id).update({'status': 'error'});
  }

  Future<void> createCoupleFortune({
    required String id,
    required String userId,
    required String femaleName,
    required String maleName,
    required String femaleZodiac,
    required String maleZodiac,
    int? femaleAge,
    int? maleAge,
    String? womanImageName,
    String? manImageName,
    DateTime? createdAt,
    DateTime? readyAt,
  }) async {
    final created = createdAt ?? DateTime.now();
    final ready = readyAt ?? computeReadyAt(created);
    await _db.collection(_couples).doc(id).set({
      'userId': userId,
      'femaleName': femaleName,
      'maleName': maleName,
      'femaleZodiac': femaleZodiac,
      'maleZodiac': maleZodiac,
      'femaleAge': ?femaleAge,
      'maleAge': ?maleAge,
      if (womanImageName != null) 'womanImageName': womanImageName,
      if (manImageName != null) 'manImageName': manImageName,
      'result': '',
      'status': 'pending',
      'createdAt': Timestamp.fromDate(created),
      'readyAt': Timestamp.fromDate(ready),
    });
  }

  Future<void> deleteCoupleFortune(String id) async {
    await _db.collection(_couples).doc(id).delete();
  }

  /// Hesap silme: kullanıcının tüm fal ve çift uyumu kayıtlarını + profil dokümanını siler.
  Future<void> deleteAllUserData(String userId) async {
    await Future.wait([
      _deleteUserDocuments(_fortunes, userId),
      _deleteUserDocuments(_couples, userId),
    ]);
    await _db.collection('users').doc(userId).delete();
  }

  Future<void> _deleteUserDocuments(String collection, String userId) async {
    final snap = await _db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .get();

    if (snap.docs.isEmpty) return;

    const batchSize = 500;
    final docs = snap.docs;
    for (var i = 0; i < docs.length; i += batchSize) {
      final batch = _db.batch();
      final end = i + batchSize < docs.length ? i + batchSize : docs.length;
      for (var j = i; j < end; j++) {
        batch.delete(docs[j].reference);
      }
      await batch.commit();
    }
  }

  Future<void> deductTokensForExistingCouple({
    required String userId,
    required String coupleId,
    required int tokenCost,
  }) async {
    try {
      final ok = await _db.runTransaction<bool>((tx) async {
        final userRef = _db.collection('users').doc(userId);
        final coupleRef = _db.collection(_couples).doc(coupleId);

        final userSnap = await tx.get(userRef);
        final coupleSnap = await tx.get(coupleRef);

        if (!coupleSnap.exists || !userSnap.exists) return false;

        final tokens = (userSnap.data()?['tokens'] as num?)?.toInt() ?? 0;
        if (tokens < tokenCost) return false;

        tx.update(userRef, {'tokens': tokens - tokenCost});
        return true;
      });
      if (!ok) {
        throw FortuneSubmitException(
          'Jeton düşülemedi veya çift uyumu isteği bulunamadı.',
        );
      }
    } on FortuneSubmitException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('COUPLE TOKEN DEDUCT FIREBASE ERROR: ${e.code} ${e.message}');
      throw FortuneSubmitException('Firestore jeton hatası: ${e.code} ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('COUPLE TOKEN DEDUCT ERROR: $e');
      debugPrint(stackTrace.toString());
      throw FortuneSubmitException('Jeton düşme hatası: $e');
    }
  }

  Future<void> updateCoupleResult(String id, String result) async {
    try {
      await _db.collection(_couples).doc(id).update({'result': result});
    } on FirebaseException catch (e) {
      debugPrint('COUPLE FIRESTORE UPDATE FIREBASE ERROR: ${e.code} ${e.message}');
      throw FortuneSubmitException(
        'Firestore sonuç kaydı hatası: ${e.code} ${e.message}',
      );
    } catch (e, stackTrace) {
      debugPrint('COUPLE FIRESTORE UPDATE ERROR: $e');
      debugPrint(stackTrace.toString());
      throw FortuneSubmitException('Firestore sonuç kaydı hatası: $e');
    }
  }

  Future<void> markCoupleReady(String id) async {
    await _db.collection(_couples).doc(id).update({'status': 'ready'});
  }

  Future<void> markCoupleError(String id) async {
    await _db.collection(_couples).doc(id).update({'status': 'error'});
  }

  FortuneReading _readingFromFields({
    required String id,
    required FortuneCategory category,
    required String summary,
    required Map<String, dynamic> d,
    List<TarotCardSelection> selectedTarotCards = const [],
  }) {
    final result = (d['result'] as String?)?.trim() ?? '';
    final createdAt = _parseCreatedAt(d['createdAt']);
    final rawStatus = d['status'] as String?;
    final readyAt = _parseOptionalDate(d['readyAt']) ??
        _parseOptionalDate(d['availableAt']);
    final usesDelayGate = readyAt != null;
    final firestoreStatus = _resolveFirestoreStatus(
      rawStatus: rawStatus,
      result: result,
      usesDelayGate: usesDelayGate,
      readyAt: readyAt,
    );

    return FortuneReading(
      id: id,
      category: category,
      status: firestoreStatus == 'ready'
          ? FortuneStatus.hazir
          : FortuneStatus.hazirlaniyor,
      createdAt: createdAt,
      summary: summary,
      result: result,
      readyAt: readyAt,
      firestoreStatus: firestoreStatus,
      usesDelayGate: usesDelayGate,
      selectedTarotCards: selectedTarotCards,
    );
  }

  String _resolveFirestoreStatus({
    required String? rawStatus,
    required String result,
    required bool usesDelayGate,
    required DateTime? readyAt,
  }) {
    if (rawStatus == 'error') return 'error';
    if (rawStatus == 'answered') return 'answered';
    if (usesDelayGate && readyAt != null) {
      final elapsed = !DateTime.now().isBefore(readyAt);
      if (elapsed && result.isNotEmpty) return 'ready';
      return rawStatus ?? 'pending';
    }
    if (rawStatus == 'ready') return 'ready';
    if (result.isNotEmpty) return 'ready';
    return rawStatus ?? 'pending';
  }

  Future<FortuneReading?> fetchFortuneById(String userId, String id) async {
    try {
      final doc = await _db.collection(_fortunes).doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || data['userId'] != userId) return null;
      return _fortuneFromData(id, data);
    } catch (e) {
      debugPrint('FIRESTORE fetchFortuneById error: $e');
      return null;
    }
  }

  Future<FortuneReading?> fetchCoupleById(String userId, String id) async {
    try {
      final doc = await _db.collection(_couples).doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || data['userId'] != userId) return null;
      return _coupleFromData(id, data);
    } catch (e) {
      debugPrint('FIRESTORE fetchCoupleById error: $e');
      return null;
    }
  }

  List<TarotCardSelection> _parseSelectedCards(Map<String, dynamic> d) {
    final raw = d['selectedCards'] ?? d['selectedTarotCards'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => TarotCardSelection.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => a.positionIndex.compareTo(b.positionIndex));
  }

  FortuneReading _fortuneFromData(String id, Map<String, dynamic> d) {
    final categoryName = d['category'] as String? ?? 'tarot';
    final category = FortuneCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => FortuneCategory.tarot,
    );
    final selectedCards = _parseSelectedCards(d);

    final inputData = d['inputData'];
    if (inputData is Map) {
      final map = Map<String, dynamic>.from(inputData);
      return _readingFromFields(
        id: id,
        category: category,
        summary: buildCategorySummary(category, map),
        d: d,
        selectedTarotCards: selectedCards,
      );
    }

    final name = d['name'] as String? ?? '';
    final age = (d['age'] as num?)?.toInt() ?? 0;
    final zodiac = d['zodiac'] as String? ?? '';
    final intention = d['intention'] as String? ?? '';
    var summary =
        '${category.label} — $name, $age, $zodiac\nNiyet: $intention';
    if (selectedCards.isNotEmpty) {
      summary += '\n${selectedCards.length} tarot kartı seçildi';
    }

    return _readingFromFields(
      id: id,
      category: category,
      summary: summary,
      d: d,
      selectedTarotCards: selectedCards,
    );
  }

  FortuneReading _fortuneFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _fortuneFromData(doc.id, doc.data());
  }

  FortuneReading _coupleFromData(String id, Map<String, dynamic> d) {
    final femaleName = d['femaleName'] as String? ?? '';
    final maleName = d['maleName'] as String? ?? '';
    final femaleZodiac = d['femaleZodiac'] as String? ?? '';
    final maleZodiac = d['maleZodiac'] as String? ?? '';
    final femaleAge = (d['femaleAge'] as num?)?.toInt();
    final maleAge = (d['maleAge'] as num?)?.toInt();

    final femalePart = femaleAge != null
        ? '$femaleName, $femaleAge, $femaleZodiac'
        : '$femaleName, $femaleZodiac';
    final malePart = maleAge != null
        ? '$maleName, $maleAge, $maleZodiac'
        : '$maleName, $maleZodiac';

    return _readingFromFields(
      id: id,
      category: FortuneCategory.ciftUyumu,
      summary: 'Kadın: $femalePart\nErkek: $malePart',
      d: d,
    );
  }

  FortuneReading _coupleFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _coupleFromData(doc.id, doc.data());
  }

  DateTime _parseCreatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  DateTime? _parseOptionalDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
