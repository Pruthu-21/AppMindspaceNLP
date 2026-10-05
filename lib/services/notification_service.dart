import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminder_model.dart';
import 'reminder_repository.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../main.dart';

@pragma('vm:entry-point')
void backgroundNotificationHandler(NotificationResponse response) {
  debugPrint('MSNLP_NOTIF: backgroundNotificationHandler called, actionId: ${response.actionId}, payload: ${response.payload}');
  WidgetsFlutterBinding.ensureInitialized();
  if (response.actionId == 'open_link') {
    debugPrint('MSNLP_NOTIF: open_link action triggered in background isolate, ignoring as it should be handled in foreground.');
    return;
  }

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
  debugPrint('MSNLP_NOTIF: foregroundNotificationHandler called, actionId: ${response.actionId}, payload: ${response.payload}');
  if (response.payload != null && response.payload!.isNotEmpty) {
    try {
      final Map<String, dynamic> data = json.decode(response.payload!);
      if (response.actionId != null) {
        data['actionId'] = response.actionId;
      }
      openMessagesFromNotification(data);
      return;
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

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
      await androidImplementation.deleteNotificationChannel('mindspace_reminders_v3');

      final channels = await androidImplementation.getNotificationChannels();
      if (channels != null) {
        for (final channel in channels) {
          if (channel.id != 'mindspace_messages_v3' && channel.id != 'mindspace_reminders_v4') {
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
          'mindspace_reminders_v4', // id
          'Reminders', // name
          description: 'Channel for alarms and reminders', // description
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('mindspace_reminder'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    }
  }

  // Define notification details with default system sound and full-screen intent
  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'mindspace_reminders_v4', // Changed ID to use new channel
        'Reminders',
        channelDescription: 'Channel for alarms and reminders',
        icon: '@mipmap/ic_launcher',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('mindspace_reminder'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
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
    Map<String, dynamic>? data,
  }) async {
    String? payload;
    if (data != null) {
      final payloadData = {
        'message_id': data['message_id'],
        'type': data['type'],
        'link': data['link'],
      };
      payload = json.encode(payloadData);
    }

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      _messageNotificationDetails(),
      payload: payload,
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
          UILocalNotificationDateInterpretation.wallClockTime,
    );
  }
  // Schedule a reminder model
  Future<bool> scheduleReminderModel(Reminder reminder) async {
    bool exactPermitted = true;
    final payload = json.encode({"type": "reminder", "id": reminder.id});

    try {
      if (reminder.repeat == RepeatType.once) {
        final scheduledDate = _nextInstanceOfTime(reminder.hour, reminder.minute);
        debugPrint('MSNLP_REMINDER: Scheduling once id ${reminder.id} at $scheduledDate');
        await flutterLocalNotificationsPlugin.zonedSchedule(
          reminder.id * 10,
          reminder.title,
          'Time for your session',
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
          payload: payload,
        );
      } else if (reminder.repeat == RepeatType.daily) {
        final scheduledDate = _nextInstanceOfTime(reminder.hour, reminder.minute);
        debugPrint('MSNLP_REMINDER: Scheduling daily id ${reminder.id} at $scheduledDate');
        await flutterLocalNotificationsPlugin.zonedSchedule(
          reminder.id * 10,
          reminder.title,
          'Time for your session',
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } else if (reminder.repeat == RepeatType.weekly) {
        for (final weekday in reminder.weekdays) {
          final scheduledDate = _nextInstanceOfWeekdayTime(reminder.hour, reminder.minute, weekday);
          final notifId = reminder.id * 10 + weekday;
          debugPrint('MSNLP_REMINDER: Scheduling weekly id ${reminder.id} weekday $weekday at $scheduledDate');
          await flutterLocalNotificationsPlugin.zonedSchedule(
            notifId,
            reminder.title,
            'Time for your session',
            scheduledDate,
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: payload,
          );
        }
      }
    } catch (e) {
      debugPrint('MSNLP_REMINDER: exact alarm failed for id ${reminder.id}, falling back to inexact. $e');
      exactPermitted = false;
      // Fallback
      try {
        if (reminder.repeat == RepeatType.once) {
          final scheduledDate = _nextInstanceOfTime(reminder.hour, reminder.minute);
          await flutterLocalNotificationsPlugin.zonedSchedule(
            reminder.id * 10,
            reminder.title,
            'Time for your session',
            scheduledDate,
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
            payload: payload,
          );
        } else if (reminder.repeat == RepeatType.daily) {
          final scheduledDate = _nextInstanceOfTime(reminder.hour, reminder.minute);
          await flutterLocalNotificationsPlugin.zonedSchedule(
            reminder.id * 10,
            reminder.title,
            'Time for your session',
            scheduledDate,
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: payload,
          );
        } else if (reminder.repeat == RepeatType.weekly) {
          for (final weekday in reminder.weekdays) {
            final scheduledDate = _nextInstanceOfWeekdayTime(reminder.hour, reminder.minute, weekday);
            final notifId = reminder.id * 10 + weekday;
            await flutterLocalNotificationsPlugin.zonedSchedule(
              notifId,
              reminder.title,
              'Time for your session',
              scheduledDate,
              _notificationDetails(),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: payload,
            );
          }
        }
      } catch (fallbackErr) {
         debugPrint('MSNLP_REMINDER: Fallback also failed: $fallbackErr');
      }
    }
    return exactPermitted;
  }

  Future<void> cancelReminder(int id) async {
    debugPrint('MSNLP_REMINDER: Cancelling reminder id $id');
    await flutterLocalNotificationsPlugin.cancel(id * 10);
    for (int i = 1; i <= 7; i++) {
      await flutterLocalNotificationsPlugin.cancel(id * 10 + i);
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int hour, int minute, int weekday) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
Future<void> rescheduleAll() async {
    final repo = ReminderRepository();
    final reminders = await repo.loadReminders();
    final now = DateTime.now();
    
    for (final reminder in reminders) {
      if (reminder.enabled) {
        if (reminder.repeat == RepeatType.once) {
          // Calculate when it was supposed to fire based on createdAt
          DateTime scheduledDate = DateTime(
              reminder.createdAt.year,
              reminder.createdAt.month,
              reminder.createdAt.day,
              reminder.hour,
              reminder.minute);
          if (scheduledDate.isBefore(reminder.createdAt)) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }
          if (scheduledDate.isBefore(now)) {
            // It has fired, disable it
            debugPrint('MSNLP_REMINDER: Disabling once reminder ${reminder.id} as it already fired');
            await repo.setEnabled(reminder.id, false);
            continue;
          }
        }
        await scheduleReminderModel(reminder);
      }
    }
  }

}
