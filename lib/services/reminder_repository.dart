import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_model.dart';

class ReminderRepository {
  static const String _key = 'mindspace_reminders_data';

  Future<List<Reminder>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_key);
    if (jsonString == null) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Reminder.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveReminders(List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(reminders.map((r) => r.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  Future<void> addReminder(Reminder reminder) async {
    final reminders = await loadReminders();
    reminders.add(reminder);
    await saveReminders(reminders);
  }

  Future<void> updateReminder(Reminder reminder) async {
    final reminders = await loadReminders();
    final index = reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      reminders[index] = reminder;
      await saveReminders(reminders);
    }
  }

  Future<void> deleteReminder(int id) async {
    final reminders = await loadReminders();
    reminders.removeWhere((r) => r.id == id);
    await saveReminders(reminders);
  }

  Future<void> setEnabled(int id, bool enabled) async {
    final reminders = await loadReminders();
    final index = reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      reminders[index] = reminders[index].copyWith(enabled: enabled);
      await saveReminders(reminders);
    }
  }
}
