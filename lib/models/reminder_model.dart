enum RepeatType { once, daily, weekly }

class Reminder {
  final int id;
  final String title;
  final int hour;
  final int minute;
  final RepeatType repeat;
  final List<int> weekdays;
  final bool enabled;
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    required this.repeat,
    required this.weekdays,
    required this.enabled,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'hour': hour,
      'minute': minute,
      'repeat': repeat.name,
      'weekdays': weekdays,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as int,
      title: json['title'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      repeat: RepeatType.values.firstWhere(
        (e) => e.name == json['repeat'],
        orElse: () => RepeatType.once,
      ),
      weekdays: List<int>.from(json['weekdays'] ?? []),
      enabled: json['enabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Reminder copyWith({
    int? id,
    String? title,
    int? hour,
    int? minute,
    RepeatType? repeat,
    List<int>? weekdays,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeat: repeat ?? this.repeat,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
