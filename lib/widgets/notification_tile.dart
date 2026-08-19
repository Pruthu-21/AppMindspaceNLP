import 'package:flutter/material.dart';
import '../models/notification_model.dart';

class NotificationTile extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const NotificationTile({
    Key? key,
    required this.notification,
    required this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  _NotifStyle _getStyle() {
    switch (widget.notification.type) {
      case 'share':
        return _NotifStyle(
          icon: Icons.folder_shared_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          glowColor: const Color(0xFF7C3AED),
          label: 'Shared',
          labelColor: const Color(0xFFDDD6FE),
        );
      case 'comment':
        return _NotifStyle(
          icon: Icons.chat_bubble_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          glowColor: const Color(0xFF0EA5E9),
          label: 'Comment',
          labelColor: const Color(0xFFBAE6FD),
        );
      case 'storage':
        return _NotifStyle(
          icon: Icons.cloud_done_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          glowColor: const Color(0xFF10B981),
          label: 'Storage',
          labelColor: const Color(0xFFA7F3D0),
        );
      case 'system':
        return _NotifStyle(
          icon: Icons.security_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          glowColor: const Color(0xFFF59E0B),
          label: 'System',
          labelColor: const Color(0xFFFDE68A),
        );
      default:
        return _NotifStyle(
          icon: Icons.notifications_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          glowColor: const Color(0xFF6366F1),
          label: 'Update',
          labelColor: const Color(0xFFC7D2FE),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final style = _getStyle();
    final isUnread = !widget.notification.isRead;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) {
          _animController.forward();
        },
        onTapUp: (_) {
          _animController.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          _animController.reverse();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isUnread
                ? LinearGradient(
                    colors: isDark
                        ? [
                            style.glowColor.withAlpha(22),
                            const Color(0xFF0F0F1A),
                          ]
                        : [
                            style.glowColor.withAlpha(10),
                            Colors.white,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isUnread ? null : (isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8F9FD)),
            border: Border.all(
              color: isUnread
                  ? style.glowColor.withAlpha(60)
                  : (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(10)),
              width: isUnread ? 1.0 : 0.8,
            ),
            boxShadow: isUnread
                ? [
                    BoxShadow(
                      color: style.glowColor.withAlpha(30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 25 : 8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated gradient icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: style.gradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: style.glowColor.withAlpha(70),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(style.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: style.glowColor.withAlpha(isDark ? 35 : 20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              style.label.toUpperCase(),
                              style: TextStyle(
                                color: style.glowColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Time
                          Text(
                            _formatRelativeTime(widget.notification.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                gradient: style.gradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: style.glowColor.withAlpha(120),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.notification.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.notification.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: isDark
                              ? (isUnread ? Colors.white70 : Colors.white38)
                              : (isUnread ? Colors.black87 : Colors.black45),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

class _NotifStyle {
  final IconData icon;
  final LinearGradient gradient;
  final Color glowColor;
  final String label;
  final Color labelColor;

  const _NotifStyle({
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.label,
    required this.labelColor,
  });
}
