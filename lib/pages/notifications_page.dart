import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../constants/mock_data.dart';
import '../models/notification_model.dart';
import '../services/auth_manager.dart';
import '../widgets/notification_tile.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  List<NotificationModel> _alerts = [];
  late AnimationController _headerAnimCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _alerts = []; // Default clean empty state like other pages
    _fetchNotifications();

    _headerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(parent: _headerAnimCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerAnimCtrl, curve: Curves.easeOutCubic));
    _headerAnimCtrl.forward();
  }

  Future<void> _fetchNotifications() async {
    if (AuthManager.token == null || AuthManager.token!.startsWith('google_token_')) return;
    try {
      final response = await http.get(
        Uri.parse('https://mindspacenlp.com/api/notifications'),
        headers: {
          'Authorization': 'Bearer ${AuthManager.token}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'] ?? body['notifications'] ?? (body is List ? body : []);
        final List<NotificationModel> loaded = data.map((item) {
          return NotificationModel(
            id: item['id']?.toString() ?? DateTime.now().toString(),
            title: item['title'] ?? item['subject'] ?? 'Notification',
            message: item['message'] ?? item['body'] ?? '',
            timestamp: DateTime.tryParse(item['created_at'] ?? item['time'] ?? '') ?? DateTime.now(),
            type: item['type'] ?? 'system',
            isRead: item['is_read'] == true || item['read'] == true,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _alerts = loaded;
          });
        }
      }
    } catch (_) {
      // Quiet failover — maintains clean empty state
    }
  }

  @override
  void dispose() {
    _headerAnimCtrl.dispose();
    super.dispose();
  }

  void _markAsRead(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _alerts[index].isRead = true;
    });
  }

  void _markAllAsRead() {
    HapticFeedback.lightImpact();
    setState(() {
      for (var alert in _alerts) {
        alert.isRead = true;
      }
    });
    _showSnack('All caught up! ✓', isSuccess: true);
  }

  void _clearAllNotifications() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Clear All?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: const Text(
            'All notifications will be removed. This cannot be undone.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _alerts.clear());
                _showSnack('Notifications cleared');
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  int get _unreadCount => _alerts.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final todayAlerts = _alerts.where((n) => _isWithinHours(n.timestamp, 24)).toList();
    final yesterdayAlerts = _alerts
        .where((n) => _isWithinHours(n.timestamp, 48) && !_isWithinHours(n.timestamp, 24))
        .toList();
    final olderAlerts = _alerts.where((n) => !_isWithinHours(n.timestamp, 48)).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070711) : const Color(0xFFF3F4F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium header
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: _buildHeader(isDark),
                ),
              ),
            ),
          ),

          // Body
          if (_alerts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(isDark),
            )
          else ...[
            if (todayAlerts.isNotEmpty) ...[
              _buildSectionHeader('Today', _unreadCount > 0 ? '$_unreadCount new' : null, isDark),
              _buildAlertList(todayAlerts),
            ],
            if (yesterdayAlerts.isNotEmpty) ...[
              _buildSectionHeader('Yesterday', null, isDark),
              _buildAlertList(yesterdayAlerts),
            ],
            if (olderAlerts.isNotEmpty) ...[
              _buildSectionHeader('Older', null, isDark),
              _buildAlertList(olderAlerts),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (_unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withAlpha(80),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _unreadCount > 0
                          ? '$_unreadCount unread alert${_unreadCount == 1 ? '' : 's'}'
                          : 'All notifications read',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Action menu
              if (_alerts.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    elevation: 8,
                    offset: const Offset(0, 44),
                    onSelected: (val) {
                      if (val == 'read_all') _markAllAsRead();
                      if (val == 'clear_all') _clearAllNotifications();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'read_all',
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.done_all_rounded,
                                  color: Color(0xFF10B981), size: 16),
                            ),
                            const SizedBox(width: 12),
                            const Text('Mark all as read', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'clear_all',
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.delete_sweep_rounded,
                                  color: Color(0xFFEF4444), size: 16),
                            ),
                            const SizedBox(width: 12),
                            const Text('Clear all',
                                style: TextStyle(
                                    color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(String title, String? badge, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 0.8,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (isDark ? Colors.white : Colors.black).withAlpha(isDark ? 25 : 15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverList _buildAlertList(List<NotificationModel> items) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final n = items[index];
          final globalIdx = _alerts.indexWhere((alert) => alert.id == n.id);
          return NotificationTile(
            notification: n,
            onTap: () => _markAsRead(globalIdx),
          );
        },
        childCount: items.length,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withAlpha(30),
                  const Color(0xFF8B5CF6).withAlpha(15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              size: 46,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No new notifications right now.\nSystem updates and alerts appear here.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _isWithinHours(DateTime time, int hours) {
    return DateTime.now().difference(time).inHours < hours;
  }
}
