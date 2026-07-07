import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:falora/models/notification_open_request.dart';
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

  final ValueNotifier<NotificationOpenRequest?> pendingOpenRequest =
      ValueNotifier<NotificationOpenRequest?>(null);

  String? _currentUserId;
  bool _localNotificationsReady = false;
  bool _openHandlersReady = false;

  Future<void> init() async {
    try {
      await _initLocalNotifications();
      _setupOpenHandlers();
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

  void _setupOpenHandlers() {
    if (_openHandlersReady) return;
    _openHandlersReady = true;

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _queueOpenFromData(message.data),
      onError: (Object e) => debugPrint('FCM open handler error: $e'),
    );

    unawaited(_captureInitialMessage());
  }

  Future<void> _captureInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (message != null) {
        _queueOpenFromData(message.data);
      }
    } catch (e) {
      debugPrint('FCM initial message error: $e');
    }
  }

  void _queueOpenFromData(Map<String, dynamic> data) {
    final request = NotificationOpenRequest.fromData(data);
    if (!request.isValid) return;
    debugPrint(
      'FCM OPEN REQUEST | type=${request.type} readingId=${request.readingId}',
    );
    pendingOpenRequest.value = request;
  }

  NotificationOpenRequest? consumePendingOpenRequest() {
    final request = pendingOpenRequest.value;
    pendingOpenRequest.value = null;
    return request;
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
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
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

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _queueOpenFromData(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('FCM local tap payload error: $e');
    }
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

    final payload = jsonEncode({
      'type': message.data['type'],
      if (message.data['readingId'] != null) 'readingId': message.data['readingId'],
      if (message.data['requestId'] != null) 'requestId': message.data['requestId'],
    });

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
      payload: payload,
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

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }

    return false;
  }

  Future<bool> enableNotificationsForUser(String userId) async {
    _currentUserId = userId;
    if (kIsWeb) {
      await _registerWebToken(userId);
    } else {
      await _registerMobileToken(userId);
    }
    return areNotificationsEnabled();
  }

  Future<void> openSystemSettings() async {
    if (kIsWeb) return;
    await openAppSettings();
  }
}
