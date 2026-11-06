import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminder_model.dart';
import '../services/reminder_repository.dart';
import '../services/notification_service.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final ReminderRepository _repo = ReminderRepository();
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  bool _exactAlarmsDenied = false;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final reminders = await _repo.loadReminders();
    if (mounted) {
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    }
  }

  String _formatTime(int hour, int minute) {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $amPm';
  }

  String _getRepeatSummary(Reminder r) {
    if (r.repeat == RepeatType.once) return 'Once';
    if (r.repeat == RepeatType.daily) return 'Every day';

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selectedDays = r.weekdays.map((w) => days[w - 1]).toList();
    return selectedDays.join(', ');
  }

  String _getTimeUntilNextRing(Reminder r) {
    if (!r.enabled) return 'Disabled';

    final now = DateTime.now();
    DateTime nextRing;

    if (r.repeat == RepeatType.once || r.repeat == RepeatType.daily) {
      nextRing = DateTime(now.year, now.month, now.day, r.hour, r.minute);
      if (nextRing.isBefore(now)) {
        nextRing = nextRing.add(const Duration(days: 1));
      }
    } else {
      if (r.weekdays.isEmpty) return 'No days selected';
      DateTime closest = now.add(const Duration(days: 365));
      for (int wd in r.weekdays) {
        DateTime candidate = DateTime(
          now.year,
          now.month,
          now.day,
          r.hour,
          r.minute,
        );
        while (candidate.weekday != wd || candidate.isBefore(now)) {
          if (candidate.weekday == wd && candidate.isAfter(now)) break;
          candidate = candidate.add(const Duration(days: 1));
        }
        if (candidate.isBefore(closest)) {
          closest = candidate;
        }
      }
      nextRing = closest;
    }

    final diff = nextRing.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours == 0 && minutes == 0) return 'Rings in less than a minute';
    if (hours == 0) return 'Rings in ${minutes}m';
    return 'Rings in ${hours}h ${minutes}m';
  }

  Future<void> _toggleReminder(Reminder r, bool val) async {
    await _repo.setEnabled(r.id, val);
    if (val) {
      final permitted = await NotificationService().scheduleReminderModel(
        r.copyWith(enabled: true),
      );
      if (!permitted && mounted) {
        setState(() => _exactAlarmsDenied = true);
      }
    } else {
      await NotificationService().cancelReminder(r.id);
    }
    _loadReminders();
  }

  Future<void> _deleteReminder(Reminder r, int index) async {
    final deleted = r;
    await _repo.deleteReminder(r.id);
    await NotificationService().cancelReminder(r.id);
    if (mounted) {
      setState(() {
        _reminders.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reminder deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _repo.addReminder(deleted);
              if (deleted.enabled) {
                await NotificationService().scheduleReminderModel(deleted);
              }
              _loadReminders();
            },
          ),
        ),
      );
    }
  }

  Future<void> _openExactAlarmSettings() async {
    final plugin = NotificationService().flutterLocalNotificationsPlugin;
    final androidImpl = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      await androidImpl.requestExactAlarmsPermission();
    }
    if (mounted) {
      setState(() {
        _exactAlarmsDenied = false;
      });
    }
  }

  void _showAddEditSheet({Reminder? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ReminderBottomSheet(
        existing: existing,
        onSave: (newReminder) async {
          if (existing != null) {
            await _repo.updateReminder(newReminder);
          } else {
            await _repo.addReminder(newReminder);
          }
          if (newReminder.enabled) {
            final permitted = await NotificationService().scheduleReminderModel(
              newReminder,
            );
            if (!permitted && mounted) {
              setState(() => _exactAlarmsDenied = true);
            }
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_getTimeUntilNextRing(newReminder))),
            );
          }
          _loadReminders();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () => _showAddEditSheet(),
          child: const Icon(Icons.add),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    if (_exactAlarmsDenied)
                      MaterialBanner(
                        padding: const EdgeInsets.all(16),
                        content: const Text(
                          'Exact alarms are not permitted, so reminders may be delayed.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: _openExactAlarmSettings,
                            child: const Text('FIX'),
                          ),
                          TextButton(
                            onPressed: () {
                              if (mounted) {
                                setState(() => _exactAlarmsDenied = false);
                              }
                            },
                            child: const Text('DISMISS'),
                          ),
                        ],
                      ),
                    Expanded(
                      child: _reminders.isEmpty
                          ? const Center(
                              child: Text(
                                'No reminders yet. Tap + to add one!',
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _reminders.length,
                              itemBuilder: (context, index) {
                                final r = _reminders[index];
                                return Dismissible(
                                  key: ValueKey(r.id),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) => _deleteReminder(r, index),
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: InkWell(
                                      onTap: () =>
                                          _showAddEditSheet(existing: r),
                                      onLongPress: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              'Delete Reminder',
                                            ),
                                            content: const Text(
                                              'Are you sure you want to delete this reminder?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _deleteReminder(r, index);
                                                },
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _formatTime(
                                                      r.hour,
                                                      r.minute,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 32,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    r.title,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${_getRepeatSummary(r)} • ${_getTimeUntilNextRing(r)}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Semantics(
                                              label: 'Toggle reminder',
                                              child: Switch(
                                                value: r.enabled,
                                                onChanged: (val) =>
                                                    _toggleReminder(r, val),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ReminderBottomSheet extends StatefulWidget {
  final Reminder? existing;
  final Function(Reminder) onSave;

  const _ReminderBottomSheet({this.existing, required this.onSave});

  @override
  State<_ReminderBottomSheet> createState() => _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends State<_ReminderBottomSheet> {
  late TextEditingController _titleController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _amPmController;

  RepeatType _repeat = RepeatType.once;
  List<int> _weekdays = [];

  final List<String> _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? 'Reminder',
    );

    int initialHour = widget.existing?.hour ?? DateTime.now().hour;
    int initialMin = widget.existing?.minute ?? DateTime.now().minute;

    int amPm = initialHour >= 12 ? 1 : 0;
    int h12 = initialHour == 0
        ? 12
        : (initialHour > 12 ? initialHour - 12 : initialHour);

    _hourController = FixedExtentScrollController(initialItem: h12 - 1);
    _minuteController = FixedExtentScrollController(initialItem: initialMin);
    _amPmController = FixedExtentScrollController(initialItem: amPm);

    if (widget.existing != null) {
      _repeat = widget.existing!.repeat;
      _weekdays = List.from(widget.existing!.weekdays);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _amPmController.dispose();
    super.dispose();
  }

  void _save() {
    if (_repeat == RepeatType.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day for weekly repeat.'),
        ),
      );
      return;
    }

    final h12 = _hourController.selectedItem + 1;
    final m = _minuteController.selectedItem;
    final amPm = _amPmController.selectedItem;

    int h24 = h12;
    if (amPm == 1 && h12 < 12) h24 += 12;
    if (amPm == 0 && h12 == 12) h24 = 0;

    final r = Reminder(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
      title: _titleController.text.trim().isEmpty
          ? 'Reminder'
          : _titleController.text.trim(),
      hour: h24,
      minute: m,
      repeat: _repeat,
      weekdays: _weekdays,
      enabled: true,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    widget.onSave(r);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Pad for keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const Text(
                'Add Reminder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Time Picker Wheels
                  SizedBox(
                    height: 150,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 70,
                          child: CupertinoPicker(
                            scrollController: _hourController,
                            itemExtent: 48,
                            selectionOverlay:
                                const CupertinoPickerDefaultSelectionOverlay(),
                            onSelectedItemChanged: (_) {
                              // Haptic feedback is automatic in CupertinoPicker
                            },
                            children: List.generate(
                              12,
                              (i) => Center(child: Text('${i + 1}')),
                            ),
                          ),
                        ),
                        const Text(
                          ':',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: CupertinoPicker(
                            scrollController: _minuteController,
                            itemExtent: 48,
                            selectionOverlay:
                                const CupertinoPickerDefaultSelectionOverlay(),
                            onSelectedItemChanged: (_) {},
                            children: List.generate(
                              60,
                              (i) => Center(
                                child: Text(i.toString().padLeft(2, '0')),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 70,
                          child: CupertinoPicker(
                            scrollController: _amPmController,
                            itemExtent: 48,
                            selectionOverlay:
                                const CupertinoPickerDefaultSelectionOverlay(),
                            onSelectedItemChanged: (_) {},
                            children: const [
                              Center(child: Text('AM')),
                              Center(child: Text('PM')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<RepeatType>(
                    segments: const [
                      ButtonSegment(
                        value: RepeatType.once,
                        label: Text('Once'),
                      ),
                      ButtonSegment(
                        value: RepeatType.daily,
                        label: Text('Daily'),
                      ),
                      ButtonSegment(
                        value: RepeatType.weekly,
                        label: Text('Weekly'),
                      ),
                    ],
                    selected: {_repeat},
                    onSelectionChanged: (Set<RepeatType> newSelection) {
                      if (mounted) {
                        setState(() {
                          _repeat = newSelection.first;
                        });
                      }
                    },
                  ),
                  if (_repeat == RepeatType.weekly) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(7, (index) {
                        final dayVal = index + 1; // 1-7 (Mon-Sun)
                        final isSelected = _weekdays.contains(dayVal);
                        return Semantics(
                          label: 'Day ${_days[index]}',
                          button: true,
                          selected: isSelected,
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 48,
                              minWidth: 48,
                            ),
                            alignment: Alignment.center,
                            child: FilterChip(
                              label: Text(_days[index]),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (mounted) {
                                  setState(() {
                                    if (selected) {
                                      _weekdays.add(dayVal);
                                    } else {
                                      _weekdays.remove(dayVal);
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
