import '../models/file_model.dart';
import '../models/review_model.dart';
import '../models/notification_model.dart';

class MockData {
  // Storage Usage
  static const double totalStorageGB = 128.0;
  static const double usedStorageGB = 64.5;
  static const double documentsGB = 12.4;
  static const double mediaGB = 34.2;
  static const double backupsGB = 10.8;
  static const double othersGB = 7.1;

  // Mock Files & Folders
  static final List<FileModel> files = [];

  // Helper getters for filtered files
  static List<FileModel> get folders => files.where((f) => f.isFolder).toList();
  static List<FileModel> get onlyFiles => files.where((f) => !f.isFolder).toList();
  static List<FileModel> get pinnedFiles => files.where((f) => f.isPinned).toList();
  static List<FileModel> get favoriteFiles => files.where((f) => f.isFavorite).toList();
  static List<FileModel> get downloadedFiles => files.where((f) => f.isDownloaded).toList();

  // Mock Notifications
  static final List<NotificationModel> notifications = [
    NotificationModel(
      id: 'n1',
      title: 'File Shared Successfully',
      message: 'Pruthu Raj shared the folder "Project MindSpace" with you.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      type: 'share',
      isRead: false,
    ),
    NotificationModel(
      id: 'n2',
      title: 'New Comment on Roadmap',
      message: 'Mannu Sharma commented: "Let\'s refine the Q3 milestones before finalizing."',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: 'comment',
      isRead: false,
    ),
    NotificationModel(
      id: 'n3',
      title: 'Storage Alert: 50% Reached',
      message: 'Your storage usage has crossed 64 GB. Consider cleaning up old files.',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      type: 'storage',
      isRead: true,
    ),
    NotificationModel(
      id: 'n4',
      title: 'System Security Update',
      message: 'Your password was successfully updated. If this wasn\'t you, contact support.',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      type: 'system',
      isRead: true,
    ),
    NotificationModel(
      id: 'n5',
      title: 'Shared File Modified',
      message: 'Mannu Sharma updated "Q3_Product_Roadmap.pdf" in Design System UX.',
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
      type: 'share',
      isRead: true,
    ),
  ];

  // Mock Reviews
  static final List<ReviewModel> reviews = [
    ReviewModel(
      id: 'r1',
      userName: 'Alexander Wright',
      userInitials: 'AW',
      rating: 5.0,
      reviewText: 'The UI is extremely fluid. Navigating folders and previews feels like Apple design. Zero latency, very premium work!',
      date: '2026-07-10',
      likes: 24,
      isLiked: true,
    ),
    ReviewModel(
      id: 'r2',
      userName: 'Sophia Martinez',
      userInitials: 'SM',
      rating: 4.5,
      reviewText: 'Excellent security features and clear layouts. Dark mode looks gorgeous. Pinned folders feature is a lifesaver for daily documents.',
      date: '2026-07-08',
      likes: 12,
    ),
    ReviewModel(
      id: 'r3',
      userName: 'Devon Keanu',
      userInitials: 'DK',
      rating: 5.0,
      reviewText: 'Absolutely brilliant. The transitions and responsive layout on my iPad are spectacular. Looking forward to the production release!',
      date: '2026-07-02',
      likes: 8,
    ),
    ReviewModel(
      id: 'r4',
      userName: 'Elena Rostova',
      userInitials: 'ER',
      rating: 4.0,
      reviewText: 'Clean design, but I hope they add folder color customization options in the future. Storage statistics screen is very informative.',
      date: '2026-06-28',
      likes: 5,
    ),
  ];
}
