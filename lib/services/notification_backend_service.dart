import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Backend üzerinden FCM bildirimi gönderme servisi.
class NotificationBackendService {
  NotificationBackendService._();

  static final NotificationBackendService instance =
      NotificationBackendService._();

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, String>> _headers() => BackendAuthClient.authHeaders();

  Future<void> _notifyReady({
    required String userId,
    required String type,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/notify-ready');
      final response = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({
              'userId': userId,
              'type': type,
            }),
          )
          .timeout(_timeout);

      BackendAuthClient.logRequest(
        '/notify-ready',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTIFY READY error: $e');
      }
    }
  }

  Future<void> notifyFortuneReady({
    required String userId,
    required bool isCouple,
  }) =>
      _notifyReady(
        userId: userId,
        type: isCouple ? 'couple' : 'fortune',
      );

  Future<void> notifyManualFortuneReady({required String userId}) =>
      _notifyReady(userId: userId, type: 'manual');

  Future<void> notifyAdminsManualRequest({
    required String requestId,
    required String readerName,
    required String categoryLabel,
    String? clientName,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/notify-admin-manual-request');
      final response = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({
              'requestId': requestId,
              'readerName': readerName,
              'categoryLabel': categoryLabel,
              if (clientName != null && clientName.isNotEmpty)
                'clientName': clientName,
            }),
          )
          .timeout(_timeout);

      BackendAuthClient.logRequest(
        '/notify-admin-manual-request',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTIFY ADMIN MANUAL REQUEST error: $e');
      }
    }
  }

  Future<void> scheduleNotify({
    required String userId,
    required bool isCouple,
    required DateTime notifyAt,
    required String readingId,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/schedule-notify');
      final response = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({
              'userId': userId,
              'type': isCouple ? 'couple' : 'fortune',
              'notifyAt': notifyAt.toUtc().toIso8601String(),
              'readingId': readingId,
            }),
          )
          .timeout(_timeout);

      BackendAuthClient.logRequest(
        '/schedule-notify',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SCHEDULE NOTIFY error: $e');
      }
    }
  }

  Future<bool> sendNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/send-notification');
      final response = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({
              'token': token,
              'title': title,
              'body': body,
            }),
          )
          .timeout(_timeout);

      BackendAuthClient.logRequest(
        '/send-notification',
        statusCode: response.statusCode,
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SEND NOTIFICATION error: $e');
      }
      return false;
    }
  }
}
