import 'dart:convert';



import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:falora/config/manual_fortune_config.dart';

import 'package:falora/models/fortune_models.dart';

import 'package:falora/models/manual_fortune_request.dart';

import 'package:falora/picked_image.dart';

import 'package:flutter/foundation.dart';



class ManualFortuneException implements Exception {

  ManualFortuneException(this.message);

  final String message;



  @override

  String toString() => message;

}



class ManualFortuneStorageService {

  ManualFortuneStorageService._();



  static final ManualFortuneStorageService instance =

      ManualFortuneStorageService._();



  static const _collection = 'manual_fortune_requests';



  final FirebaseFirestore _db = FirebaseFirestore.instance;



  String newRequestId() => _db.collection(_collection).doc().id;

  static List<Map<String, String>> encodeImagesForPayload(
    List<PickedImage>? images,
  ) {
    if (images == null || images.isEmpty) return const [];

    return images
        .map(
          (img) => {
            'name': img.name,
            'mime': _mimeForNameStatic(img.name),
            'base64': base64Encode(img.bytes),
          },
        )
        .toList();
  }



  Future<List<FortuneReading>> loadUserReadings(String userId) async {

    try {

      final snap = await _db

          .collection(_collection)

          .where('userId', isEqualTo: userId)

          .get();

      final readings = snap.docs

          .map((d) => ManualFortuneRequest.fromFirestore(d.id, d.data()))

          .map((r) => r.toFortuneReading())

          .toList()

        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return readings;

    } catch (e) {

      debugPrint('MANUAL REQUEST CREATE ERROR load: $e');

      return [];

    }

  }



  Stream<ManualFortuneRequest?> watchRequest(String id) {

    return _db.collection(_collection).doc(id).snapshots().map((snap) {

      if (!snap.exists) return null;

      return ManualFortuneRequest.fromFirestore(snap.id, snap.data()!);

    });

  }



  Stream<List<ManualFortuneRequest>> watchPendingForAdmin() {

    debugPrint('ADMIN REQUESTS LISTEN START');

    return _db

        .collection(_collection)

        .where('status', isEqualTo: 'pending')

        .snapshots()

        .map((snap) {

      debugPrint('ADMIN_PENDING_REQUESTS_COUNT: ${snap.docs.length}');

      final items = snap.docs

          .map((d) => ManualFortuneRequest.fromFirestore(d.id, d.data()))

          .toList()

        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return items;

    });

  }



  Future<void> createRequest({

    required String id,

    required String userId,

    required String userEmail,

    required FortuneCategory category,

    required String readerId,

    required String readerName,

    required ManualFortuneOffer offer,

    required int tokenCost,

    required String name,

    required int age,

    required String zodiac,

    required String intention,

    required List<String> questions,

    List<PickedImage>? images,

  }) async {

    debugPrint('MANUAL REQUEST SUBMIT START id=$id reader=$readerId');

    debugPrint('MANUAL QUESTION_LIMIT: ${offer.questionLimit}');

    final imageInfo = encodeImagesForPayload(images);



    try {

      await _db.collection(_collection).doc(id).set({

        'userId': userId,

        'userEmail': userEmail,

        'fortuneType': category.name,

        'readerId': readerId,

        'readerName': readerName,

        'tokenCost': tokenCost,

        'priceTRY': 0,

        'questionLimit': offer.questionLimit,

        'requiresIntention': offer.requiresIntention,

        'status': 'pending',

        'name': name,

        'age': age,

        'zodiac': zodiac,

        'intention': intention,

        'questions': questions,

        if (imageInfo.isNotEmpty) 'imageInfo': imageInfo,

        'paymentStatus': 'tokens',

        'createdAt': FieldValue.serverTimestamp(),

      });

      debugPrint('MANUAL REQUEST CREATE SUCCESS id=$id');

      debugPrint('MANUAL REQUEST CREATED id=$id tokenCost=$tokenCost');

    } catch (e, stack) {

      debugPrint('MANUAL REQUEST CREATE ERROR: $e');

      debugPrint(stack.toString());

      rethrow;

    }

  }



  Stream<List<ManualFortuneRequest>> watchAnsweredForAdmin() {
    return _db
        .collection(_collection)
        .where('status', isEqualTo: 'answered')
        .snapshots()
        .map((snap) {
      debugPrint('ADMIN_ANSWERED_REQUESTS_COUNT: ${snap.docs.length}');
      final items = snap.docs
          .map((d) => ManualFortuneRequest.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) {
          final aTime = a.answeredAt ?? a.createdAt;
          final bTime = b.answeredAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
      return items;
    });
  }

  Future<void> updateAdminAnswer({
    required String requestId,
    required String answerText,
    required String adminUid,
    PickedImage? answerImage,
    bool clearAnswerImage = false,
  }) async {
    debugPrint('ADMIN_ANSWER_UPDATE_START id=$requestId');
    final updates = <String, dynamic>{
      'answerText': answerText.trim(),
      'status': 'answered',
      'answeredByAdminUid': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (answerImage != null) {
      updates['answerImageInfo'] = {
        'name': answerImage.name,
        'mime': _mimeForName(answerImage.name),
        'base64': base64Encode(answerImage.bytes),
      };
    } else if (clearAnswerImage) {
      updates['answerImageInfo'] = FieldValue.delete();
    }

    try {
      await _db.collection(_collection).doc(requestId).update(updates);
      debugPrint('ADMIN_ANSWER_UPDATE_SUCCESS id=$requestId');
    } catch (e, stack) {
      debugPrint('ADMIN_ANSWER_UPDATE_ERROR: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Future<void> submitAdminAnswer({

    required String requestId,

    required String answerText,

    required String adminUid,

    PickedImage? answerImage,

  }) async {

    debugPrint('ADMIN ANSWER SUBMIT START id=$requestId');

    final updates = <String, dynamic>{

      'answerText': answerText.trim(),

      'status': 'answered',

      'answeredAt': FieldValue.serverTimestamp(),

      'answeredByAdminUid': adminUid,

    };

    if (answerImage != null) {

      updates['answerImageInfo'] = {

        'name': answerImage.name,

        'mime': _mimeForName(answerImage.name),

        'base64': base64Encode(answerImage.bytes),

      };

    }



    try {

      await _db.collection(_collection).doc(requestId).update(updates);

      debugPrint('ADMIN ANSWER SUBMIT SUCCESS id=$requestId');

    } catch (e, stack) {

      debugPrint('ADMIN ANSWER SUBMIT ERROR: $e');

      debugPrint(stack.toString());

      rethrow;

    }

  }



  Future<void> deleteUserRequests(String userId) async {

    final snap = await _db

        .collection(_collection)

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
  String _mimeForName(String name) {
    return _mimeForNameStatic(name);

  }

  static String _mimeForNameStatic(String name) {
    final lower = name.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';

    if (lower.endsWith('.webp')) return 'image/webp';

    return 'image/jpeg';
  }

}

