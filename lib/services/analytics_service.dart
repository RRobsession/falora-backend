import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics bootstrap — native SDK first_open / session_start için şart.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics instance = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: instance);

  /// Firebase.initializeApp sonrası çağır.
  static Future<void> init() async {
    try {
      await instance.setAnalyticsCollectionEnabled(true);
      // session_start / engagement için uygulama açılışını işaretle
      await instance.logAppOpen();
      debugPrint(
        'ANALYTICS INIT OK collection=true '
        'debug=$kDebugMode',
      );
    } catch (e, st) {
      debugPrint('ANALYTICS INIT ERROR: $e');
      debugPrint('$st');
    }
  }
}
