import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({Key? key}) : super(key: key);

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  DateTime? _selectedTime;
  String _savedReminder = "No reminder set.";

  @override
  void initState() {
    super.initState();
    _loadReminder();
  }

  Future<void> _loadReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final reminderString = prefs.getString('user_reminder');
    if (reminderString != null) {
      setState(() {
        _savedReminder = "Reminder set for: $reminderString";
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (picked != null) {
      final now = DateTime.now();
      DateTime newTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      
      if (newTime.isBefore(now)) {
        newTime = newTime.add(const Duration(days: 1));
      }

      setState(() {
        _selectedTime = newTime;
      });

      await _saveReminder();
    }
  }

  Future<void> _saveReminder() async {
    if (_selectedTime == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_reminder', _selectedTime!.toString());

    await NotificationService().scheduleReminder(
      id: 0,
      title: 'Mindspace Reminder',
      body: 'It is time for your scheduled Mindspace session.',
      scheduledDate: _selectedTime!,
    );

    setState(() {
      _savedReminder = "Reminder set for: ${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}";
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder Scheduled!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Reminders'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set a daily reminder. You will receive a notification with the custom Mindspace sound.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              _savedReminder,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _selectTime(context),
              child: const Text('Select Time'),
            ),
            const SizedBox(height: 10),
            if (_selectedTime != null)
              Text(
                'Selected: ${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
