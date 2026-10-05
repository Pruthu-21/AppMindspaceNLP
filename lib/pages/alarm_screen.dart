import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/reminder_model.dart';
import '../services/reminder_repository.dart';
import '../services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  final int reminderId;
  final String title;

  const AlarmScreen({
    super.key,
    required this.reminderId,
    required this.title,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  static const _channel = MethodChannel('mindspace/app');
  final AudioPlayer _player = AudioPlayer();
  final ReminderRepository _repo = ReminderRepository();
  
  late String _targetCode;
  String _enteredCode = '';
  List<int> _keypad = [];
  int _snoozeCount = 0;
  Timer? _timeTimer;
  DateTime _now = DateTime.now();
  bool _wrongCode = false;

  @override
  void initState() {
    super.initState();
    _setWindowFlags(true);
    _startTimer();
    _playAlarm();
    _generateCodeAndShuffle();
  }

  void _setWindowFlags(bool enable) {
    try {
      _channel.invokeMethod('setAlarmWindowFlags', {'enable': enable});
    } catch (e) {
      debugPrint('Error setting window flags: $e');
    }
  }

  void _startTimer() {
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _playAlarm() async {
    await _player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        usageType: AndroidUsageType.alarm,
        contentType: AndroidContentType.music,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    ));
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('audio/mindspace_reminder.mp3'));
  }

  void _generateCodeAndShuffle() {
    final rand = Random.secure();
    _targetCode = List.generate(4, (_) => rand.nextInt(10).toString()).join();
    _keypad = List.generate(10, (i) => i)..shuffle(rand);
    _enteredCode = '';
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _player.stop();
    _player.dispose();
    _setWindowFlags(false);
    super.dispose();
  }

  void _onKeyPressed(int digit) {
    if (_enteredCode.length < 4) {
      setState(() {
        _enteredCode += digit.toString();
        _wrongCode = false;
      });
      if (_enteredCode.length == 4) {
        _checkCode();
      }
    }
  }

  void _onBackspace() {
    if (_enteredCode.isNotEmpty) {
      setState(() {
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
        _wrongCode = false;
      });
    }
  }

  Future<void> _checkCode() async {
    if (_enteredCode == _targetCode) {
      debugPrint('MSNLP_REMINDER: correct code entered for id ${widget.reminderId}');
      await _stopAndDismiss(disableIfOnce: true);
    } else {
      debugPrint('MSNLP_REMINDER: wrong code entered for id ${widget.reminderId}');
      setState(() {
        _wrongCode = true;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _generateCodeAndShuffle();
          });
        }
      });
    }
  }

  Future<void> _snooze() async {
    if (_snoozeCount >= 3) return;
    debugPrint('MSNLP_REMINDER: snooze pressed for id ${widget.reminderId}');
    _snoozeCount++;
    await NotificationService().cancelReminder(widget.reminderId);
    
    // schedule one-off
    final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
    // We just use zonedSchedule with absoluteTime
    final reminder = Reminder(
      id: widget.reminderId,
      title: '${widget.title} (Snoozed)',
      hour: snoozeTime.hour,
      minute: snoozeTime.minute,
      repeat: RepeatType.once,
      weekdays: [],
      enabled: true,
      createdAt: DateTime.now(),
    );
    await NotificationService().scheduleReminderModel(reminder);
    
    await _stopAndDismiss(disableIfOnce: false);
  }

  Future<void> _stopAndDismiss({required bool disableIfOnce}) async {
    await NotificationService().cancelReminder(widget.reminderId);
    if (disableIfOnce) {
      final reminders = await _repo.loadReminders();
      final index = reminders.indexWhere((r) => r.id == widget.reminderId);
      if (index != -1 && reminders[index].repeat == RepeatType.once) {
        await _repo.setEnabled(widget.reminderId, false);
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour == 0 ? 12 : (_now.hour > 12 ? _now.hour - 12 : _now.hour);
    final amPm = _now.hour >= 12 ? 'PM' : 'AM';
    final m = _now.minute.toString().padLeft(2, '0');

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$h:$m $amPm',
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 32),
                      const Text('Enter code to dismiss:'),
                      const SizedBox(height: 8),
                      Text(
                        _targetCode,
                        style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          String char = '';
                          if (i < _enteredCode.length) {
                            char = _enteredCode[i];
                          }
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 24,
                            child: Text(
                              char.isEmpty ? '_' : char,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _wrongCode ? Colors.red : null,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: 12,
                        itemBuilder: (ctx, index) {
                          if (index == 9) return const SizedBox.shrink();
                          if (index == 11) {
                            return Semantics(
                              label: 'Backspace',
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: _onBackspace,
                                child: const Icon(Icons.backspace),
                              ),
                            );
                          }
                          final digit = index == 10 ? _keypad[9] : _keypad[index];
                          return Semantics(
                            label: 'Digit $digit',
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => _onKeyPressed(digit),
                              child: Text(
                                digit.toString(),
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      if (_snoozeCount < 3)
                        ElevatedButton.icon(
                          onPressed: _snooze,
                          icon: const Icon(Icons.snooze),
                          label: const Text('Snooze 10 min'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
