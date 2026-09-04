import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/ai_config.dart';
import 'package:falora/models/problem_report.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/services/notification_backend_service.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/utils/upload_image_prepare.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ProblemReportException implements Exception {
  ProblemReportException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Kullanıcı sorun bildirimleri — Firestore `problem_reports`.
class ProblemReportService {
  ProblemReportService._();

  static final ProblemReportService instance = ProblemReportService._();

  static const _collection = 'problem_reports';
  static const maxDescriptionLength = 2000;
  static const resolvedRetention = Duration(days: 1);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createReport({
    required String userId,
    required String userEmail,
    required String displayName,
    required String description,
    required String platform,
    PickedImage? image,
    bool imageAlreadyPrepared = false,
    void Function(String phase)? onPhase,
  }) async {
    final text = description.trim();
    if (text.isEmpty) {
      throw ProblemReportException('Lütfen sorunu kısaca yazın.');
    }
    if (text.length > maxDescriptionLength) {
      throw ProblemReportException(
        'Açıklama en fazla $maxDescriptionLength karakter olabilir.',
      );
    }

    List<Map<String, String>> imageInfo = const [];
    if (image != null && image.bytes.isNotEmpty) {
      // Spinner'ın boyanması için bir frame bırak.
      await Future<void>.delayed(Duration.zero);

      PickedImage prepared = image;
      if (!imageAlreadyPrepared) {
        onPhase?.call('Görsel hazırlanıyor…');
        prepared = await prepareProblemReportImageForUpload(image);
      }

      final payloadChars = estimateBase64PayloadChars([prepared]);
      if (payloadChars > problemReportMaxImagePayloadChars) {
        throw ProblemReportException(
          'Görsel çok büyük. Lütfen daha küçük bir ekran görüntüsü seçin.',
        );
      }

      onPhase?.call('Görsel kodlanıyor…');
      await Future<void>.delayed(Duration.zero);
      imageInfo = [await encodeImageForFirestorePayload(prepared)];

      if (kDebugMode) {
        debugPrint(
          'PROBLEM_REPORT IMAGE prepared=${prepared.bytes.length}B '
          'payload~${payloadChars ~/ 1024}KB',
        );
      }
    }

    onPhase?.call('Gönderiliyor…');
    await Future<void>.delayed(Duration.zero);

    try {
      final report = await _db.collection(_collection).add({
        'userId': userId,
        'userEmail': userEmail.trim(),
        'displayName': displayName.trim(),
        'description': text,
        'platform': platform,
        'status': 'open',
        'imageInfo': imageInfo,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      unawaited(
        NotificationBackendService.instance.notifyAdminsProblemReport(
          reportId: report.id,
        ),
      );
    } catch (e) {
      debugPrint('PROBLEM_REPORT CREATE ERROR: $e');
      throw ProblemReportException(
        'Sorun bildirimi gönderilemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  Stream<List<ProblemReport>> watchOpenForAdmin() {
    return _db
        .collection(_collection)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snap) {
          final items =
              snap.docs
                  .map((d) => ProblemReport.fromFirestore(d.id, d.data()))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Stream<List<ProblemReport>> watchResolvedForAdmin() {
    return _db
        .collection(_collection)
        .where('status', isEqualTo: 'resolved')
        .snapshots()
        .map((snap) {
          final items =
              snap.docs
                  .map((d) => ProblemReport.fromFirestore(d.id, d.data()))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Stream<List<ProblemReport>> watchOpenForUser(String userId) => _db
      .collection(_collection)
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map(
        (snap) =>
            snap.docs
                .map((d) => ProblemReport.fromFirestore(d.id, d.data()))
                .where((r) => r.isOpen)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  Stream<List<Map<String, dynamic>>> watchMessages(String reportId) => _db
      .collection(_collection)
      .doc(reportId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<void> sendMessage({
    required String reportId,
    required String text,
    required bool admin,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 1500) {
      throw ProblemReportException('Mesaj 1-1500 karakter olmalı.');
    }
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/support/messages'),
          headers: await BackendAuthClient.authHeaders(),
          body: jsonEncode({
            'reportId': reportId,
            'text': clean,
            'senderRole': admin ? 'admin' : 'user',
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode >= 300) {
      var message = 'Destek mesajı gönderilemedi.';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['error'] is String) message = data['error'];
      } catch (_) {}
      throw ProblemReportException(message);
    }
  }

  Future<void> markResolved({
    required String reportId,
    required String adminUid,
    String adminNote = '',
  }) async {
    final purgeAt = DateTime.now().add(resolvedRetention);
    await _db.collection(_collection).doc(reportId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'purgeAt': Timestamp.fromDate(purgeAt),
      'resolvedByAdminUid': adminUid,
      'adminNote': adminNote.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 1 günden eski çözülen bildirimleri siler (birikmesin).
  Future<int> purgeExpiredResolvedReports() async {
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(resolvedRetention);
      final snap = await _db
          .collection(_collection)
          .where('status', isEqualTo: 'resolved')
          .get();

      if (snap.docs.isEmpty) return 0;

      final toDelete = <DocumentReference>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final purgeAt = data['purgeAt'];
        if (purgeAt is Timestamp && !purgeAt.toDate().isAfter(now)) {
          toDelete.add(doc.reference);
          continue;
        }
        final resolvedAt = data['resolvedAt'];
        final updatedAt = data['updatedAt'];
        DateTime? when;
        if (resolvedAt is Timestamp) {
          when = resolvedAt.toDate();
        } else if (updatedAt is Timestamp) {
          when = updatedAt.toDate();
        }
        if (when != null && !when.isAfter(cutoff)) {
          toDelete.add(doc.reference);
        }
      }

      if (toDelete.isEmpty) return 0;

      // Firestore batch max 500.
      for (var i = 0; i < toDelete.length; i += 450) {
        final chunk = toDelete.skip(i).take(450);
        final batch = _db.batch();
        for (final ref in chunk) {
          batch.delete(ref);
        }
        await batch.commit();
      }

      if (kDebugMode) {
        debugPrint(
          'PROBLEM_REPORT PURGE deleted=${toDelete.length} '
          '(older than ${resolvedRetention.inDays}d)',
        );
      }
      return toDelete.length;
    } catch (e) {
      debugPrint('PROBLEM_REPORT PURGE ERROR: $e');
      return 0;
    }
  }

  static String detectPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }
}
