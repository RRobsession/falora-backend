import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/models/manual_fortune_reader.dart';
import 'package:falora/models/manual_reader_status.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ManualReaderStatusSnapshot {
  const ManualReaderStatusSnapshot({
    this.serdar = ManualReaderStatus.auto,
    this.hatice = ManualReaderStatus.auto,
    this.serdarVisible = true,
    this.haticeVisible = true,
    this.statuses = const {},
    this.visibility = const {},
  });

  static const empty = ManualReaderStatusSnapshot();

  final ManualReaderStatus serdar;
  final ManualReaderStatus hatice;
  final bool serdarVisible;
  final bool haticeVisible;
  final Map<String, ManualReaderStatus> statuses;
  final Map<String, bool> visibility;

  ManualReaderStatus forReader(String readerId) =>
      statuses[readerId] ?? (readerId == 'hatice' ? hatice : serdar);

  bool isVisible(String readerId) =>
      visibility[readerId] ??
      (readerId == 'hatice' ? haticeVisible : serdarVisible);
}

/// Firestore: `manual_reader_status/current`
class ManualReaderStatusService {
  ManualReaderStatusService._();

  static final ManualReaderStatusService instance =
      ManualReaderStatusService._();

  static const _collection = 'manual_reader_status';
  static const _docId = 'current';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection).doc(_docId);

  bool _boolOrTrue(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      final t = value.trim().toLowerCase();
      if (t == 'false' || t == '0') return false;
      if (t == 'true' || t == '1') return true;
    }
    return true;
  }

  ManualReaderStatusSnapshot _fromData(Map<String, dynamic>? data) {
    if (data == null) return ManualReaderStatusSnapshot.empty;
    return ManualReaderStatusSnapshot(
      serdar: ManualReaderStatusX.fromCode(data['serdar']?.toString()),
      hatice: ManualReaderStatusX.fromCode(data['hatice']?.toString()),
      serdarVisible: _boolOrTrue(data['serdarVisible']),
      haticeVisible: _boolOrTrue(data['haticeVisible']),
      statuses: Map<String, dynamic>.from(data['statuses'] ?? const {}).map(
        (key, value) =>
            MapEntry(key, ManualReaderStatusX.fromCode(value?.toString())),
      ),
      visibility: Map<String, dynamic>.from(
        data['visibility'] ?? const {},
      ).map((key, value) => MapEntry(key, _boolOrTrue(value))),
    );
  }

  Future<ManualReaderStatusSnapshot> fetch() async {
    try {
      final snap = await _ref.get();
      return _fromData(snap.data());
    } catch (e) {
      debugPrint('MANUAL READER STATUS FETCH ERROR: $e');
      return ManualReaderStatusSnapshot.empty;
    }
  }

  Stream<ManualReaderStatusSnapshot> watch() {
    return _ref.snapshots().map((snap) => _fromData(snap.data()));
  }

  Future<void> setStatus({
    required String readerId,
    required ManualReaderStatus status,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _db.runTransaction((tx) async {
      final current = (await tx.get(_ref)).data() ?? <String, dynamic>{};
      final statuses = Map<String, dynamic>.from(
        current['statuses'] ?? const {},
      );
      statuses[readerId] = status.code;
      tx.set(_ref, {
        'statuses': statuses,
        'updatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'updatedBy': uid,
      }, SetOptions(merge: true));
    });
    debugPrint(
      'MANUAL READER STATUS SET reader=$readerId status=${status.code}',
    );
  }

  Future<void> setBoth({
    required ManualReaderStatus serdar,
    required ManualReaderStatus hatice,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _ref.set({
      'serdar': serdar.code,
      'hatice': hatice.code,
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Future<void> setVisibility({
    required String readerId,
    required bool visible,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _db.runTransaction((tx) async {
      final current = (await tx.get(_ref)).data() ?? <String, dynamic>{};
      final visibility = Map<String, dynamic>.from(
        current['visibility'] ?? const {},
      );
      visibility[readerId] = visible;
      tx.set(_ref, {
        'visibility': visibility,
        'updatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'updatedBy': uid,
      }, SetOptions(merge: true));
    });
    debugPrint(
      'MANUAL READER VISIBILITY SET reader=$readerId visible=$visible',
    );
  }

  String readerDisplayName(String readerId) =>
      manualReaderById(readerId)?.name ?? readerId;

  static String hiddenMessage(String readerName) =>
      '$readerName şu an müşterilere görünmüyor.';
}
