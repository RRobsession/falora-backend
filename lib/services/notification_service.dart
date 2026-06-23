import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _androidChannelId = 'falora_ready';
  static const _androidChannelName = 'Falora Bildirimleri';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _currentUserId;
  bool _localNotificationsReady = false;

  Future<void> init() async {
    try {
      await _initLocalNotifications();
      if (kIsWeb) {
        await _initWeb();
        return;
      }
      await _requestPermissions();
      _setupForegroundListener();
      _messaging.onTokenRefresh.listen(
        _onTokenRefresh,
        onError: (Object e) => debugPrint('FCM token refresh error: $e'),
      );
    } catch (e) {
      debugPrint('FCM INIT ERROR: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: 'Fal ve çift uyumu hazır bildirimleri',
          importance: Importance.high,
        ),
      );
    }

    _localNotificationsReady = true;
  }

  Future<void> _initWeb() async {
    try {
      _setupForegroundListener();
      _messaging.onTokenRefresh.listen(
        _onTokenRefresh,
        onError: (Object _) => debugPrint('FCM WEB TOKEN SKIPPED'),
      );
    } catch (_) {
      debugPrint('FCM WEB TOKEN SKIPPED');
    }
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM iOS permission: ${settings.authorizationStatus}');
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      debugPrint('FCM Android permission: $status');
      return status.isGranted;
    }

    return true;
  }

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen(
      (message) async {
        debugPrint(
          'FCM FOREGROUND MESSAGE: id=${message.messageId} '
          'title=${message.notification?.title} '
          'body=${message.notification?.body} '
          'data=${message.data}',
        );
        await _showForegroundNotification(message);
      },
      onError: (Object e) {
        if (kIsWeb) {
          debugPrint('FCM WEB TOKEN SKIPPED');
        } else {
          debugPrint('FCM foreground listener error: $e');
        }
      },
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsReady || kIsWeb) return;

    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null || title.isEmpty || body == null || body.isEmpty) {
      return;
    }

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: 'Fal ve çift uyumu hazır bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> registerForUser(String userId) async {
    _currentUserId = userId;
    if (kIsWeb) {
      await _registerWebToken(userId);
      return;
    }
    await _registerMobileToken(userId);
  }

  Future<void> _registerWebToken(String userId) async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM WEB TOKEN SKIPPED');
        return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM WEB TOKEN SKIPPED');
        return;
      }

      debugPrint('FCM TOKEN FOUND (web): ${token.substring(0, 12)}...');
      await _saveToken(userId, token);
    } catch (_) {
      debugPrint('FCM WEB TOKEN SKIPPED');
    }
  }

  Future<void> _registerMobileToken(String userId) async {
    try {
      final granted = await _requestPermissions();
      if (!granted) {
        debugPrint('FCM TOKEN NOT FOUND | reason=permission_denied');
        return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM TOKEN NOT FOUND | reason=unavailable');
        return;
      }

      debugPrint('FCM TOKEN FOUND: ${token.substring(0, 12)}...');
      await _saveToken(userId, token);
    } catch (e) {
      debugPrint('FCM TOKEN error: $e');
    }
  }

  Future<void> unregisterForUser(String? userId) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('FCM clear token error: $e');
    }
    _currentUserId = null;
  }

  /// Hesap silme: Firestore token kaydını ve cihaz push token'ını temizler.
  Future<void> clearForAccountDeletion(String userId) async {
    try {
      await unregisterForUser(userId);
      if (!kIsWeb) {
        await _messaging.deleteToken();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM account deletion cleanup error: $e');
      }
    }
    _currentUserId = null;
  }

  Future<void> _onTokenRefresh(String token) async {
    debugPrint('FCM TOKEN FOUND (refresh): ${token.substring(0, 12)}...');
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await _saveToken(uid, token);
    } catch (e) {
      if (kIsWeb) {
        debugPrint('FCM WEB TOKEN SKIPPED');
      } else {
        debugPrint('FCM save token error: $e');
      }
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    await _db.collection('users').doc(userId).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
    debugPrint('FCM TOKEN saved for userId=$userId');
  }
}
