import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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

  Future<void> init() async {
    tz.initializeTimeZones();

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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
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
      },
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationHandler,
    );
  }

  // Define notification details with default system sound and full-screen intent
  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'mindspace_channel_id_3', // Changed ID to force sound update
        'Mindspace Reminders',
        channelDescription: 'Alarm and Reminder Notifications for Mindspace app',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        fullScreenIntent: true,
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
      _notificationDetails(),
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
