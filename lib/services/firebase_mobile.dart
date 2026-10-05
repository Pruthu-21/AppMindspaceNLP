import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'message_service.dart';

import 'notification_service.dart';

Future<void> setupFirebase(MessageService messageService, String? userToken) async {
  if (kIsWeb) return;
  
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.requestPermission();
  
  // Set iOS foreground notification presentation options
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  final fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint('Your Device FCM Token is: $fcmToken');
  
  if (userToken != null && fcmToken != null) {
    await messageService.updateFcmToken(userToken, fcmToken);
  }

  // Handle foreground notifications for Android using flutter_local_notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground notification received: ${message.messageId}');
    if (message.notification != null) {
      NotificationService().showNotification(
        id: message.hashCode,
        title: message.notification?.title ?? 'Notification',
        body: message.notification?.body ?? '',
      );
    }
  });
}
