import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'message_service.dart';

import 'notification_service.dart';
import '../main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.notification == null &&
      message.data['link'] != null &&
      message.data['link'].toString().isNotEmpty) {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Minimal init for background
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: foregroundNotificationHandler,
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationHandler,
    );

    final title = message.data['title'] ?? 'New Message';
    final body = message.data['body'] ?? '';

    final payloadData = Map<String, dynamic>.from(message.data);

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'mindspace_messages_v3',
      'Messages',
      channelDescription: 'Channel for general messages',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('mindspace_alert'),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'open_link',
          'Open link',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      platformChannelSpecifics,
      payload: json.encode(payloadData),
    );
  }
}

Future<void> initFirebaseOnly() async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

Future<void> setupFirebase(
  MessageService messageService,
  String? userToken,
) async {
  if (kIsWeb) return;

  try {
    await Firebase.initializeApp();
  } catch (_) {}
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

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    openMessagesFromNotification(message.data);
  });

  // Handle foreground notifications using AppToast instead of outside notification
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground notification received: ${message.messageId}');

    final context = navigatorKey.currentState?.context;
    if (context == null || !context.mounted) return;

    // Play a basic system sound (since we are bypassing the local notification)
    SystemSound.play(SystemSoundType.click);

    if (message.notification != null) {
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? '';
      AppToast.showInfo(context, '$title\n$body');
    } else if (message.data['link'] != null &&
        message.data['link'].toString().isNotEmpty) {
      final title = message.data['title'] ?? 'New Message';
      final body = message.data['body'] ?? '';
      final link = message.data['link'].toString();

      AppToast.showInfo(
        context,
        '$title\n$body',
        actionLabel: 'Open link',
        onAction: () {
          final uri = Uri.tryParse(link);
          if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
            try {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (e) {
              debugPrint('Error launching url from in-app toast: $e');
            }
          }
        },
      );
    }
  });
}

Future<Map<String, dynamic>?> getInitialMessageData() async {
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  return initialMessage?.data;
}
