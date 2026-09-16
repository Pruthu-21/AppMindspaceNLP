import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'message_service.dart';

Future<void> setupFirebase(MessageService messageService, String? userToken) async {
  if (kIsWeb) return;
  
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.requestPermission();
  final fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint('Your Device FCM Token is: $fcmToken');
  
  if (userToken != null && fcmToken != null) {
    await messageService.updateFcmToken(userToken, fcmToken);
  }
}
