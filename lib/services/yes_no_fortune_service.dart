import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/models/tarot_card.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:http/http.dart' as http;

class YesNoFortuneException implements Exception {
  const YesNoFortuneException(this.message);
  final String message;
  @override
  String toString() => message;
}

class YesNoFortuneService {
  const YesNoFortuneService();

  Future<String> generate({
    required String question,
    required List<TarotCardSelection> cards,
    required bool paidWithAd,
  }) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/generate-yes-no'),
          headers: await BackendAuthClient.authHeaders(),
          body: jsonEncode({
            'question': question.trim(),
            'cards': cards.map((card) => card.toApiMap()).toList(),
            'paymentMethod': paidWithAd ? 'ad' : 'token',
          }),
        )
        .timeout(const Duration(seconds: 60));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw YesNoFortuneException(
        body['error'] as String? ?? 'Fal yorumlanamadı.',
      );
    }
    final result = (body['result'] as String? ?? '').trim();
    if (result.isEmpty) {
      throw const YesNoFortuneException('Fal yorumu boş geldi.');
    }
    return result;
  }
}
