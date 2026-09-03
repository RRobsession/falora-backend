import 'dart:convert';
import 'dart:typed_data';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:http/http.dart' as http;

class AdminReaderAvatarAiService {
  AdminReaderAvatarAiService._();
  static final instance = AdminReaderAvatarAiService._();

  Future<Uint8List> generate({
    required String name,
    required String gender,
    required String title,
  }) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/admin/manual-reader-avatar-ai'),
          headers: await BackendAuthClient.authHeaders(),
          body: jsonEncode({
            'name': name.trim(),
            'gender': gender,
            'title': title.trim(),
          }),
        )
        .timeout(const Duration(minutes: 2));
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } on FormatException {
      if (response.statusCode == 404 || response.body.contains('<!DOCTYPE')) {
        throw Exception(
          'AI görsel servisi sunucuda henüz yayınlanmamış. Backend deploy edilmelidir.',
        );
      }
      throw Exception('AI görsel servisi geçersiz bir yanıt döndürdü.');
    }
    if (response.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Profil görseli oluşturulamadı.');
    }
    final encoded = data['imageBase64']?.toString() ?? '';
    if (encoded.isEmpty) throw Exception('AI boş bir görsel döndürdü.');
    return base64Decode(encoded);
  }
}
