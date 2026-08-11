import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/ai_config.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Günlük burç — Firestore okuma + admin yayınlama.
class DailyHoroscopeService {
  DailyHoroscopeService._();

  static final DailyHoroscopeService instance = DailyHoroscopeService._();

  static const _timeout = Duration(seconds: 60);
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Türkiye UTC+3 tarih anahtarı (YYYY-MM-DD) — Firestore / API.
  static String istanbulDateKey([DateTime? utcNow]) {
    final now = (utcNow ?? DateTime.now().toUtc()).add(
      const Duration(hours: 3),
    );
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Türkiye tarihi görüntüleme: GG-AA-YYYY.
  static String istanbulDateDisplay([DateTime? utcNow]) {
    final key = istanbulDateKey(utcNow);
    final parts = key.split('-');
    if (parts.length != 3) return key;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  /// YYYY-MM-DD → GG-AA-YYYY.
  static String formatDateKeyForDisplay(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  Future<DailyHoroscope?> fetchForDate(String dateKey) async {
    final snap =
        await _db.collection('daily_horoscopes').doc(dateKey).get();
    if (!snap.exists || snap.data() == null) return null;
    return DailyHoroscope.fromMap(snap.id, snap.data()!);
  }

  Future<DailyHoroscope?> fetchToday() => fetchForDate(istanbulDateKey());

  Future<String?> textForZodiac({
    required String zodiac,
    String? dateKey,
  }) async {
    final doc = await fetchForDate(dateKey ?? istanbulDateKey());
    if (doc == null) return null;
    return doc.textFor(zodiac);
  }

  Future<DailyHoroscopePublishResult> publish({
    required Map<String, String> signs,
    String? dateKey,
    bool sendNotifications = true,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/admin/daily-horoscope');
    final response = await http
        .post(
          uri,
          headers: await BackendAuthClient.authHeaders(),
          body: jsonEncode({
            'signs': signs,
            if (dateKey != null) 'date': dateKey,
            'sendNotifications': sendNotifications,
          }),
        )
        .timeout(_timeout);

    BackendAuthClient.logRequest(
      '/admin/daily-horoscope',
      statusCode: response.statusCode,
    );

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode != 200) {
      throw DailyHoroscopeException(
        body['error']?.toString() ??
            'Yayınlama başarısız (${response.statusCode})',
      );
    }

    return DailyHoroscopePublishResult.fromJson(body);
  }

  Future<Map<String, String>?> loadAdminDraft(String dateKey) async {
    try {
      final uri = Uri.parse(
        '$apiBaseUrl/admin/daily-horoscope?date=${Uri.encodeQueryComponent(dateKey)}',
      );
      final response = await http
          .get(uri, headers: await BackendAuthClient.authHeaders())
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final horoscope = body['horoscope'];
      if (horoscope is! Map) return null;
      final signs = horoscope['signs'];
      if (signs is! Map) return null;
      final out = <String, String>{};
      for (final z in burclar) {
        final v = signs[z];
        if (v != null) out[z] = v.toString();
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('DAILY HOROSCOPE DRAFT LOAD: $e');
      return null;
    }
  }
}

class DailyHoroscope {
  const DailyHoroscope({
    required this.date,
    required this.signs,
  });

  final String date;
  final Map<String, String> signs;

  String? textFor(String zodiac) {
    final key = zodiac.trim();
    final direct = signs[key];
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    return null;
  }

  factory DailyHoroscope.fromMap(String id, Map<String, dynamic> data) {
    final raw = data['signs'];
    final signs = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v != null) signs[k.toString()] = v.toString();
      });
    }
    return DailyHoroscope(
      date: data['date']?.toString() ?? id,
      signs: signs,
    );
  }
}

class DailyHoroscopePublishResult {
  const DailyHoroscopePublishResult({
    required this.date,
    required this.notifyStats,
  });

  final String date;
  final Map<String, dynamic> notifyStats;

  int get totalSent {
    var n = 0;
    for (final v in notifyStats.values) {
      if (v is Map && v['sent'] is num) n += (v['sent'] as num).toInt();
    }
    return n;
  }

  factory DailyHoroscopePublishResult.fromJson(Map<String, dynamic> json) {
    final stats = json['notifyStats'];
    return DailyHoroscopePublishResult(
      date: json['date']?.toString() ?? '',
      notifyStats: stats is Map
          ? Map<String, dynamic>.from(stats)
          : const {},
    );
  }
}

class DailyHoroscopeException implements Exception {
  DailyHoroscopeException(this.message);
  final String message;

  @override
  String toString() => message;
}
