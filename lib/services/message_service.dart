import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppMessage {
  final String id;
  final String title;
  final String body;
  final String? attachmentUrl;
  final DateTime createdAt;

  AppMessage({
    required this.id,
    required this.title,
    required this.body,
    this.attachmentUrl,
    required this.createdAt,
  });

  factory AppMessage.fromJson(Map<String, dynamic> json) {
    return AppMessage(
      id: json['id'].toString(),
      title: json['title'],
      body: json['body'],
      attachmentUrl: json['attachment_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class MessageService {
  // Replace with your actual API endpoint URL
  final String baseUrl = 'https://mindspacenlp.com/api';
  
  static final ValueNotifier<bool> hasUnreadMessages = ValueNotifier(false);

  Future<void> checkUnreadMessages(String userToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/messages'),
        headers: {
          'Authorization': 'Bearer $userToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        List<dynamic> data = [];
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] is List) data = decoded['data'];
          else if (decoded['messages'] is List) data = decoded['messages'];
        }
        
        if (data.isNotEmpty) {
          final firstId = data.first['id'].toString();
          final prefs = await SharedPreferences.getInstance();
          final lastReadId = prefs.getString('last_read_message_id');
          if (lastReadId != firstId) {
            hasUnreadMessages.value = true;
          }
        }
      }
    } catch (e) {
      print('Error checking unread messages: $e');
    }
  }

  Future<List<AppMessage>> fetchMessages(String userToken) async {
    List<AppMessage> messages = [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/messages'),
        headers: {
          'Authorization': 'Bearer $userToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        List<dynamic> data = [];
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] is List) data = decoded['data'];
          else if (decoded['messages'] is List) data = decoded['messages'];
        }
        final fetchedMessages = data.map((json) => AppMessage.fromJson(json)).toList();
        messages.addAll(fetchedMessages);
        
        // Mark as read
        if (messages.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_read_message_id', messages.first.id);
          hasUnreadMessages.value = false;
        }
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }

    return messages;
  }

  Future<bool> sendAdminMessage({
    required String adminToken,
    required String title,
    required String body,
    String? attachmentUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/messages'),
        headers: {
          'Authorization': 'Bearer $adminToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'title': title,
          'body': body,
          if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachment_url': attachmentUrl,
        }),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }
  
  Future<void> updateOnlineStatus(String userToken, bool isOnline) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/user/status'),
        headers: {
          'Authorization': 'Bearer $userToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'is_online': isOnline,
        }),
      );
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  Future<void> updateFcmToken(String userToken, String fcmToken) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/user/fcm-token'),
        headers: {
          'Authorization': 'Bearer $userToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'token': fcmToken,
        }),
      );
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  Future<bool> sendReportIssue({
    required String userToken,
    required String subject,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/queries'),
        headers: {
          'Authorization': 'Bearer $userToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'subject': subject,
          'message': message,
        }),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error sending issue report: $e');
      return false;
    }
  }
}
