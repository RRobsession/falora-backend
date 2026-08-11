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
  });

  static const empty = ManualReaderStatusSnapshot();

  final ManualReaderStatus serdar;
  final ManualReaderStatus hatice;
  final bool serdarVisible;
  final bool haticeVisible;

  ManualReaderStatus forReader(String readerId) =>
      readerId == 'hatice' ? hatice : serdar;

  bool isVisible(String readerId) =>
      readerId == 'hatice' ? haticeVisible : serdarVisible;
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
    if (readerId != 'serdar' && readerId != 'hatice') {
      throw ArgumentError('Geçersiz yorumcu: $readerId');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _ref.set(
      {
        readerId: status.code,
        'updatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'updatedBy': uid,
      },
      SetOptions(merge: true),
    );
    debugPrint(
      'MANUAL READER STATUS SET reader=$readerId status=${status.code}',
    );
  }

  Future<void> setBoth({
    required ManualReaderStatus serdar,
    required ManualReaderStatus hatice,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _ref.set(
      {
        'serdar': serdar.code,
        'hatice': hatice.code,
        'updatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'updatedBy': uid,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setVisibility({
    required String readerId,
    required bool visible,
  }) async {
    if (readerId != 'serdar' && readerId != 'hatice') {
      throw ArgumentError('Geçersiz yorumcu: $readerId');
    }
    final field = readerId == 'hatice' ? 'haticeVisible' : 'serdarVisible';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _ref.set(
      {
        field: visible,
        'updatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'updatedBy': uid,
      },
      SetOptions(merge: true),
    );
    debugPrint(
      'MANUAL READER VISIBILITY SET reader=$readerId visible=$visible',
    );
  }

  String readerDisplayName(String readerId) =>
      manualReaderById(readerId)?.name ?? readerId;

  static String hiddenMessage(String readerName) =>
      '$readerName şu an müşterilere görünmüyor.';
}
