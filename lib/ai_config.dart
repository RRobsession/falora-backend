import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Production backend (Railway).
const String productionApiBaseUrl =
    'https://falora-backend-production-6602.up.railway.app';

/// Yerel backend portu (sadece debug-local).
const int apiPort = 3000;

/// Fiziksel Android cihaz + yerel backend için bilgisayarın WiFi IP'si.
/// flutter run --dart-define=USE_LOCAL_API=true --dart-define=DEV_LAN_HOST=192.168.1.42
const String devLanHost = String.fromEnvironment(
  'DEV_LAN_HOST',
  defaultValue: '192.168.1.101',
);

/// Yerel backend ile geliştirme (yalnızca debug):
/// flutter run --dart-define=USE_LOCAL_API=true
const bool useLocalApi = bool.fromEnvironment(
  'USE_LOCAL_API',
  defaultValue: false,
);

/// `true` → backend üzerinden gerçek AI; `false` → yerel MockAiService.
const bool useRealAi = true;

/// Uygulama genelinde kullanılan backend base URL.
/// [initApiConfig] çağrılmadan önce erişilmemelidir.
late String apiBaseUrl;

/// Platforma göre API base URL'ini belirler ve loglar.
Future<void> initApiConfig() async {
  apiBaseUrl = await _resolveApiBaseUrl();
  if (!kDebugMode && !apiBaseUrl.startsWith('https://')) {
    throw StateError('Production build requires HTTPS API endpoint.');
  }
  if (kDebugMode) {
    debugPrint('API_BASE_URL: $apiBaseUrl');
    if (useLocalApi) {
      debugPrint('API_MODE: debug-local');
    } else {
      debugPrint('API_MODE: production (Railway)');
    }
  }
}

Future<String> _resolveApiBaseUrl() async {
  // Release, profile ve varsayılan debug → Railway.
  if (!kDebugMode || !useLocalApi) {
    return productionApiBaseUrl;
  }

  return _resolveLocalDebugApiBaseUrl();
}

Future<String> _resolveLocalDebugApiBaseUrl() async {
  if (kIsWeb) {
    return 'http://127.0.0.1:$apiPort';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    final isEmulator = await _isAndroidEmulator();
    if (isEmulator) {
      return 'http://10.0.2.2:$apiPort';
    }
    return 'http://$devLanHost:$apiPort';
  }

  return 'http://127.0.0.1:$apiPort';
}

Future<bool> _isAndroidEmulator() async {
  try {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return !androidInfo.isPhysicalDevice;
  } catch (e) {
    debugPrint('Emulator detection failed, assuming physical device: $e');
    return false;
  }
}

/// Geriye dönük uyumluluk.
String get aiBackendUrl => apiBaseUrl;
