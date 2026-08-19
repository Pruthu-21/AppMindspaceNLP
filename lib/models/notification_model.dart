class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type; // 'share', 'comment', 'system', 'storage'
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });
}
