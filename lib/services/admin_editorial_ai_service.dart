import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:http/http.dart' as http;

class AdminEditorialAiService {
  AdminEditorialAiService._();
  static final instance = AdminEditorialAiService._();

  Future<Map<String, dynamic>> generate({
    required String type,
    required String date,
    int? count,
  }) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/admin/editorial-ai'),
          headers: await BackendAuthClient.authHeaders(),
          body: jsonEncode({
            'type': type,
            'date': date,
            if (count != null) 'count': count,
          }),
        )
        .timeout(const Duration(minutes: 3));
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } on FormatException {
      if (response.statusCode == 404 || response.body.contains('<!DOCTYPE')) {
        throw Exception(
          'AI içerik servisi sunucuda henüz yayınlanmamış. Backend deploy edilmelidir.',
        );
      }
      throw Exception('AI servisi geçersiz bir yanıt döndürdü.');
    }
    if (response.statusCode >= 300) {
      throw Exception(data['error'] ?? 'AI içeriği oluşturulamadı');
    }
    return data;
  }
}
