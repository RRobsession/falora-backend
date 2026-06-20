import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:falora/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    'FCM BACKGROUND MESSAGE: id=${message.messageId} '
    'title=${message.notification?.title} '
    'body=${message.notification?.body} '
    'data=${message.data}',
  );
}
