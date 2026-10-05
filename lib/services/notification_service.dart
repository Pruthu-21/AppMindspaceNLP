import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

@pragma('vm:entry-point')
void backgroundNotificationHandler(NotificationResponse response) {
  if (response.actionId == 'snooze_id') {
    tz.initializeTimeZones(); // Ensure timezones are initialized in background isolate
    // Schedule for 10 minutes later
    final now = DateTime.now();
    final snoozeTime = now.add(const Duration(minutes: 10));
    NotificationService().scheduleReminder(
      id: 0,
      title: 'Mindspace Reminder (Snoozed)',
      body: 'It is time for your scheduled Mindspace session.',
      scheduledDate: snoozeTime,
    );
  }
}

@pragma('vm:entry-point')
void foregroundNotificationHandler(NotificationResponse response) {
  if (response.actionId == 'snooze_id') {
    // Schedule for 10 minutes later
    final now = DateTime.now();
    final snoozeTime = now.add(const Duration(minutes: 10));
    NotificationService().scheduleReminder(
      id: 0,
      title: 'Mindspace Reminder (Snoozed)',
      body: 'It is time for your scheduled Mindspace session.',
      scheduledDate: snoozeTime,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: foregroundNotificationHandler,
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationHandler,
    );

    // Create Android channels
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.deleteNotificationChannel('mindspace_messages');
      await androidImplementation.deleteNotificationChannel('mindspace_reminders');
      await androidImplementation.deleteNotificationChannel('mindspace_messages_v2');
      await androidImplementation.deleteNotificationChannel('mindspace_reminders_v2');

      final channels = await androidImplementation.getNotificationChannels();
      if (channels != null) {
        for (final channel in channels) {
          if (channel.id != 'mindspace_messages_v3' && channel.id != 'mindspace_reminders_v3') {
            print('Found old/other channel id: ${channel.id}');
          }
        }
      }

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'mindspace_messages_v3', // id
          'Messages', // name
          description: 'Channel for general messages', // description
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('mindspace_alert'),
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'mindspace_reminders_v3', // id
          'Reminders', // name
          description: 'Channel for alarms and reminders', // description
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('mindspace_alert'),
        ),
      );
    }
  }

  // Define notification details with default system sound and full-screen intent
  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'mindspace_reminders_v3', // Changed ID to use new channel
        'Reminders',
        channelDescription: 'Channel for alarms and reminders',
        icon: '@mipmap/ic_launcher',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('mindspace_alert'),
        category: AndroidNotificationCategory.alarm,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'stop_id',
            'Stop',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'snooze_id',
            'Snooze (10 mins)',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
      ),
    );
  }

  NotificationDetails _messageNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'mindspace_messages_v3', // Changed ID to use new channel
        'Messages',
        channelDescription: 'Channel for general messages',
        icon: '@mipmap/ic_launcher',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('mindspace_alert'),
      ),
      iOS: DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
      ),
    );
  }

  // Show immediate notification (e.g., received from background API / websockets)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      _messageNotificationDetails(),
    );
  }

  // Schedule a reminder notification
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
