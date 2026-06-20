import 'package:falora/ai_config.dart';
import 'package:falora/mock_ai_service.dart';
import 'package:falora/openai_backend_service.dart';
import 'package:falora/picked_image.dart';

/// Kullanıcıya gösterilecek genel hata mesajı.
const String aiErrorMessage =
    'AI yorumu şu anda oluşturulamadı. Lütfen tekrar deneyin.';

const String coupleErrorMessage =
    'Uyum raporu oluşturulamadı, lütfen tekrar deneyin.';

bool isFortuneResultError(String result) =>
    result == aiErrorMessage || result == coupleErrorMessage;

/// Fal ve çift uyumu yorumlarını üreten servis sözleşmesi.
abstract class AiService {
  Future<String> generateFortune({
    required String category,
    required String name,
    required int age,
    required String zodiac,
    required String intention,
    required String tellerId,
    List<String> imageNames = const [],
  });

  Future<String> generateCoupleCompatibility({
    required String womanName,
    required int womanAge,
    required String womanZodiac,
    required String manName,
    required int manAge,
    required String manZodiac,
    PickedImage? womanImage,
    PickedImage? manImage,
  });
}

/// [useRealAi] bayrağına göre uygun servisi döndürür.
AiService createAiService() =>
    useRealAi ? OpenAiBackendService() : MockAiService();
