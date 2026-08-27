import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/utils/upload_image_prepare.dart';
import 'package:http/http.dart' as http;

class FortuneImageValidationException implements Exception {
  const FortuneImageValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FortuneImageValidationService {
  FortuneImageValidationService._();

  static final instance = FortuneImageValidationService._();

  Future<void> validate({
    required String kind,
    required List<PickedImage> images,
    required List<String> slots,
  }) async {
    if (images.length != slots.length || images.isEmpty) {
      throw const FortuneImageValidationException(
        'Gerekli fotoğrafların tamamını ekleyin.',
      );
    }
    if (images.any((image) => image.bytes.isEmpty)) {
      throw const FortuneImageValidationException(
        'Fotoğraflardan biri okunamadı. Lütfen yeniden seçin.',
      );
    }
    if (_containsExactDuplicate(images)) {
      throw const FortuneImageValidationException(
        'Aynı fotoğrafı birden fazla alanda kullanamazsınız.',
      );
    }

    final prepared = await Future.wait(images.map(prepareImageForUpload));
    final payload = <String, dynamic>{
      'kind': kind,
      'images': [
        for (var index = 0; index < prepared.length; index++)
          {
            'slot': slots[index],
            'name': prepared[index].name,
            'mime': _mimeFor(prepared[index].name),
            'base64': base64Encode(prepared[index].bytes),
          },
      ],
    };

    try {
      final headers = await BackendAuthClient.authHeaders();
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/validate-fortune-images'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 90));
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FortuneImageValidationException(
          body['error']?.toString() ??
              'Fotoğraflar doğrulanamadı. Lütfen tekrar deneyin.',
        );
      }
      if (body['valid'] != true) {
        throw FortuneImageValidationException(
          body['message']?.toString() ??
              'Fotoğraflar bu fal türüne uygun görünmüyor.',
        );
      }
    } on FortuneImageValidationException {
      rethrow;
    } catch (_) {
      throw const FortuneImageValidationException(
        'Fotoğraf kontrolü şu anda tamamlanamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  bool _containsExactDuplicate(List<PickedImage> images) {
    for (var first = 0; first < images.length; first++) {
      for (var second = first + 1; second < images.length; second++) {
        final a = images[first].bytes;
        final b = images[second].bytes;
        if (a.length != b.length) continue;
        var equal = true;
        for (var index = 0; index < a.length; index++) {
          if (a[index] != b[index]) {
            equal = false;
            break;
          }
        }
        if (equal) return true;
      }
    }
    return false;
  }

  String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
