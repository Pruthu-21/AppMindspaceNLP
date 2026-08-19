import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';
import '../services/auth_manager.dart';

class ChatMessage {
  final String id;
  final String senderEmail;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isFromAdmin;

  ChatMessage({
    required this.id,
    required this.senderEmail,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.isFromAdmin,
  });
}

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({Key? key}) : super(key: key);

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  static const String adminEmail = 'mindspace0123@gmail.com';

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _fetchChatMessages();
  }

  void _loadInitialMessages() {
    final user = AuthManager.currentUser;
    final userEmail = user?.email ?? 'User';
    final userName = user?.name ?? 'User';

    // Default 1-to-1 greeting from MindSpace Admin
    _messages = [
      ChatMessage(
        id: '1',
        senderEmail: adminEmail,
        senderName: 'MindSpace Support Admin',
        message: 'Hello $userName! Welcome to MindSpace Support. How can I assist you today?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isFromAdmin: true,
      ),
    ];
  }

  Future<void> _fetchChatMessages() async {
    if (AuthManager.token == null || AuthManager.token!.startsWith('google_token_')) return;
    try {
      final response = await http.get(
        Uri.parse('https://mindspacenlp.com/api/chat/messages'),
        headers: {
          'Authorization': 'Bearer ${AuthManager.token}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'] ?? body['messages'] ?? (body is List ? body : []);
        final currentUserEmail = AuthManager.currentUser?.email ?? '';

        final loaded = data.map((item) {
          final sender = item['sender_email'] ?? item['email'] ?? '';
          return ChatMessage(
            id: item['id']?.toString() ?? DateTime.now().toString(),
            senderEmail: sender,
            senderName: item['sender_name'] ?? item['name'] ?? 'User',
            message: item['message'] ?? item['body'] ?? '',
            timestamp: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            isFromAdmin: sender.toString().toLowerCase() == adminEmail.toLowerCase() || item['is_admin'] == true,
          );
        }).toList();

        if (loaded.isNotEmpty && mounted) {
          setState(() {
            _messages = loaded;
          });
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = AuthManager.currentUser;
    final userEmail = user?.email ?? 'User';
    final userName = user?.name ?? 'User';
    final isUserAdmin = userEmail.toLowerCase() == adminEmail.toLowerCase() || user?.role.name == 'admin';

    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderEmail: userEmail,
      senderName: userName,
      message: text,
      timestamp: DateTime.now(),
      isFromAdmin: isUserAdmin,
    );

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });
    _scrollToBottom();

    // Call Laravel API endpoint if token available
    if (AuthManager.token != null && !AuthManager.token!.startsWith('google_token_')) {
      try {
        await http.post(
          Uri.parse('https://mindspacenlp.com/api/chat/send'),
          headers: {
            'Authorization': 'Bearer ${AuthManager.token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'recipient': adminEmail,
            'message': text,
          }),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              child: const Center(
                child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Support Chat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  adminEmail,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = !msg.isFromAdmin;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.primary
                            : (isDark ? AppColors.surfaceDark : Colors.grey.shade200),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        border: isMe
                            ? null
                            : Border.all(
                                color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
                              ),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                msg.senderName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          Text(
                            msg.message,
                            style: TextStyle(
                              fontSize: 14,
                              color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 9,
                              color: isMe ? Colors.white70 : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Message Input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Message $adminEmail...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
