import 'dart:convert';



import 'package:falora/ai_config.dart';

import 'package:falora/ai_service.dart';

import 'package:falora/picked_image.dart';

import 'package:falora/services/backend_auth_client.dart';

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



  static const _timeout = Duration(seconds: 120);



  @override

  Future<String> generateFortune({

    required String category,

    required String name,

    required int age,

    required String zodiac,

    required String intention,

    required String tellerId,

    List<String> imageNames = const [],

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

        'imageNames': imageNames,

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



  String _imageMime(String name) {

    final lower = name.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';

    if (lower.endsWith('.webp')) return 'image/webp';

    if (lower.endsWith('.gif')) return 'image/gif';

    return 'image/jpeg';

  }



  Future<String> _post(String path, Map<String, dynamic> body) async {

    final uri = Uri.parse('$_baseUrl$path');



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

      throw AiBackendException(e.message);

    } catch (e, stackTrace) {

      if (kDebugMode) {

        debugPrint('AI ERROR: $e');

        debugPrint(stackTrace.toString());

      }

      throw AiBackendException('Bağlantı hatası: $e');

    }



    BackendAuthClient.logRequest(

      path,

      statusCode: response.statusCode,

    );



    if (response.statusCode == 401 || response.statusCode == 403) {

      throw AiBackendException('Oturum doğrulanamadı. Lütfen tekrar giriş yapın.');

    }



    if (response.statusCode != 200) {

      throw AiBackendException('HTTP ${response.statusCode}');

    }



    try {

      final result = _parseResult(response.body);

      BackendAuthClient.logRequest(path, statusCode: 200, resultLength: result.length);

      return result;

    } catch (e, stackTrace) {

      if (kDebugMode) {

        debugPrint('AI PARSE ERROR: $e');

        debugPrint(stackTrace.toString());

      }

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



    return text;

  }

}



class AiBackendException implements Exception {

  AiBackendException(this.message);

  final String message;



  @override

  String toString() => message;

}


