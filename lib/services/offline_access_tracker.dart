import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_storage.dart';
import 'auth_manager.dart';

class OfflineAccessTracker {
  static const String _storageKey = 'pending_offline_access_logs';
  static Timer? _syncTimer;

  static void _startSyncTimer() {
    if (_syncTimer != null && _syncTimer!.isActive) return;
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final String? existingJson = await AppStorage.read(_storageKey);
        if (existingJson == null || existingJson.isEmpty) {
          timer.cancel();
          _syncTimer = null;
          return;
        }
        final List<dynamic> logs = jsonDecode(existingJson) as List<dynamic>;
        if (logs.isEmpty) {
          timer.cancel();
          _syncTimer = null;
          return;
        }
        await syncPendingLogs();
      } catch (_) {
        // Keep retrying on next timer tick
      }
    });
  }

  /// Track a file access event. If online, send directly to server; if offline or request fails, store locally for silent sync later.
  static Future<void> trackAccess(String fileId, {String? fileName}) async {
    if (fileId.isEmpty) return;

    final token = AuthManager.token;
    bool synced = false;

    if (token != null && !token.startsWith('google_token_')) {
      try {
        final response = await http.post(
          Uri.parse('https://mindspacenlp.com/api/drive/file/$fileId/access'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'file_name': fileName,
            'accessed_at': DateTime.now().toIso8601String(),
            'increment_open': true,
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 || response.statusCode == 201) {
          synced = true;
        }
      } catch (_) {
        synced = false;
      }
    }

    if (!synced) {
      await _storeLocally(fileId, fileName: fileName);
    } else {
      // Trigger silent sync of any previously stored offline logs
      syncPendingLogs();
    }
  }

  /// Store un-synced file access log locally.
  static Future<void> _storeLocally(String fileId, {String? fileName}) async {
    try {
      final String? existingJson = await AppStorage.read(_storageKey);
      List<dynamic> logs = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        logs = jsonDecode(existingJson) as List<dynamic>;
      }

      logs.add({
        'file_id': fileId,
        'file_name': fileName ?? 'File #$fileId',
        'accessed_at': DateTime.now().toIso8601String(),
      });

      await AppStorage.write(_storageKey, jsonEncode(logs));
      _startSyncTimer();
    } catch (_) {}
  }

  /// Silently upload all locally stored offline file access logs to the server when connected.
  static Future<void> syncPendingLogs() async {
    try {
      final String? existingJson = await AppStorage.read(_storageKey);
      if (existingJson == null || existingJson.isEmpty) return;

      final List<dynamic> logs = jsonDecode(existingJson) as List<dynamic>;
      if (logs.isEmpty) return;

      final token = AuthManager.token;
      if (token == null || token.startsWith('google_token_')) {
        _startSyncTimer();
        return;
      }

      final List<dynamic> remaining = [];
      final DateTime now = DateTime.now();

      for (var log in logs) {
        final String fileId = log['file_id'].toString();
        final String accessedAtStr = log['accessed_at'] ?? now.toIso8601String();
        final DateTime accessedAt = DateTime.tryParse(accessedAtStr) ?? now;

        // Discard log if it's older than 15 days
        if (now.difference(accessedAt).inDays > 15) {
          continue;
        }

        try {
          final response = await http.post(
            Uri.parse('https://mindspacenlp.com/api/drive/file/$fileId/access'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'file_name': log['file_name'],
              'accessed_at': log['accessed_at'],
              'offline_synced': true,
              'increment_open': true,
            }),
          ).timeout(const Duration(seconds: 4));

          if (response.statusCode != 200 && response.statusCode != 201) {
            remaining.add(log);
          }
        } catch (_) {
          remaining.add(log);
        }
      }

      if (remaining.isEmpty) {
        await AppStorage.delete(_storageKey);
        if (_syncTimer != null) {
          _syncTimer!.cancel();
          _syncTimer = null;
        }
      } else {
        await AppStorage.write(_storageKey, jsonEncode(remaining));
        _startSyncTimer();
      }
    } catch (_) {
      _startSyncTimer();
    }
  }
}
