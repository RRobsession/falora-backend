import 'dart:convert';



import 'package:falora/ai_config.dart';

import 'package:falora/ai_service.dart';

import 'package:falora/models/tarot_card.dart';
import 'package:falora/picked_image.dart';

import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/services/fortune_submit_logger.dart';
import 'package:falora/utils/ai_result_sanitize.dart';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;



/// OpenAI çağrılarını güvenli backend proxy üzerinden yapan servis.

/// Flutter uygulaması doğrudan OpenAI'a istek atmaz.

class OpenAiBackendService implements AiService {

  OpenAiBackendService({http.Client? client, String? baseUrl})

      : _client = client ?? http.Client(),

        _baseUrl = baseUrl ?? apiBaseUrl;



  final http.Client _client;

  final String _baseUrl;



  static const _timeout = Duration(seconds: 180);



  @override

  Future<String> generateFortune({

    required String category,

    required String name,

    required int age,

    required String zodiac,

    required String intention,

    required String tellerId,

    String? requestId,

    List<String> imageNames = const [],

    List<TarotCardSelection> selectedTarotCards = const [],

  }) async {

    BackendAuthClient.logRequest('/generate-fortune');

    return _post(

      '/generate-fortune',

      {

        'category': category,

        'name': name,

        'age': age.toString(),

        'zodiac': zodiac,

        'intention': intention,

        'tellerId': tellerId,

        if (requestId != null && requestId.isNotEmpty) 'requestId': requestId,

        'imageNames': imageNames,

        if (selectedTarotCards.isNotEmpty)
          'selectedCards':
              selectedTarotCards.map((c) => c.toApiMap()).toList(),

      },

    );

  }



  @override

  Future<String> generateCoupleCompatibility({

    required String womanName,

    required int womanAge,

    required String womanZodiac,

    required String manName,

    required int manAge,

    required String manZodiac,

    String? requestId,

    PickedImage? womanImage,

    PickedImage? manImage,

  }) async {

    final body = <String, dynamic>{

      'womanName': womanName,

      'womanAge': womanAge.toString(),

      'womanZodiac': womanZodiac,

      'manName': manName,

      'manAge': manAge.toString(),

      'manZodiac': manZodiac,

    };

    if (requestId != null && requestId.isNotEmpty) {
      body['requestId'] = requestId;
    }

    if (womanImage != null) {

      body['womanImageBase64'] = base64Encode(womanImage.bytes);

      body['womanImageMime'] = _imageMime(womanImage.name);

      body['womanImageName'] = womanImage.name;

      if (kDebugMode) {

        debugPrint('COUPLE VISION woman bytes=${womanImage.bytes.length}');

      }

    }

    if (manImage != null) {

      body['manImageBase64'] = base64Encode(manImage.bytes);

      body['manImageMime'] = _imageMime(manImage.name);

      body['manImageName'] = manImage.name;

      if (kDebugMode) {

        debugPrint('COUPLE VISION man bytes=${manImage.bytes.length}');

      }

    }



    BackendAuthClient.logRequest('/generate-couple');

    return _post('/generate-couple', body);

  }



  @override

  Future<String> generateCategoryReading({

    required String categoryType,

    required Map<String, dynamic> inputData,

    String? requestId,

    List<PickedImage> chatImages = const [],

  }) async {

    BackendAuthClient.logRequest('/generate-fortune');

    final body = <String, dynamic>{

      'categoryType': categoryType,

      'inputData': inputData,

      if (requestId != null && requestId.isNotEmpty) 'requestId': requestId,

    };

    if (chatImages.isNotEmpty) {

      body['chatImages'] = [

        for (final image in chatImages.take(3))

          {

            'base64': base64Encode(image.bytes),

            'mime': _imageMime(image.name),

            'name': image.name,

          },

      ];

    }

    return _post(

      '/generate-fortune',

      body,

    );

  }



  String _imageMime(String name) {

    final lower = name.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';

    if (lower.endsWith('.webp')) return 'image/webp';

    if (lower.endsWith('.gif')) return 'image/gif';

    return 'image/jpeg';

  }



  Future<String> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');

    await FortuneSubmitLogger.logSubmitStart(
      fortuneType: body['category']?.toString() ?? 'unknown',
      selectedReader: body['tellerId']?.toString() ?? 'unknown',
      isManualReader: false,
      endpoint: uri.toString(),
      requestBody: body,
    );

    late final http.Response response;
    try {
      final headers = await BackendAuthClient.authHeaders();
      response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on BackendAuthException catch (e) {
      FortuneSubmitLogger.logError(e);
      throw AiBackendException(e.message);
    } catch (e, stackTrace) {
      FortuneSubmitLogger.logError(e, stackTrace);
      throw AiBackendException('Bağlantı hatası: $e');
    }

    FortuneSubmitLogger.logResponse(
      status: response.statusCode,
      body: response.body,
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AiBackendException('Oturum doğrulanamadı. Lütfen tekrar giriş yapın.');
    }

    if (response.statusCode != 200) {
      throw AiBackendException('HTTP ${response.statusCode}');
    }

    try {
      final result = _parseResult(response.body);
      if (kDebugMode) {
        debugPrint('AI $path result length=${result.length}');
      }
      return result;
    } catch (e, stackTrace) {
      FortuneSubmitLogger.logError(e, stackTrace);
      throw AiBackendException('Yanıt parse edilemedi: $e');
    }
  }



  String _parseResult(String body) {

    final dynamic data = jsonDecode(body);

    if (data is! Map) {

      throw FormatException('Beklenen JSON obje, gelen: ${data.runtimeType}');

    }



    final result = data['result'];

    if (result == null) {

      throw FormatException('result alanı yok');

    }



    final text = result.toString().trim();

    if (text.isEmpty) {

      throw FormatException('result alanı boş');

    }



    return sanitizeAiResult(text);

  }

}



class AiBackendException implements Exception {

  AiBackendException(this.message);

  final String message;



  @override

  String toString() => message;

}


