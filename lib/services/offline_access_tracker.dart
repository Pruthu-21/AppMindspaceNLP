import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_storage.dart';
import 'auth_manager.dart';

class OfflineAccessTracker {
  static const String _storageKey = 'pending_offline_access_logs';
  static Timer? _syncTimer;
  static final Map<String, int> _sessionTimes = {};

  
  static int getSessionTime(String fileId) => _sessionTimes[fileId] ?? 0;
  
  static int addSessionTime(String fileId, int incrementSeconds) {
    final current = _sessionTimes[fileId] ?? 0;
    _sessionTimes[fileId] = current + incrementSeconds;
    return _sessionTimes[fileId]!;
  }

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
  static Future<void> trackAccess(
    String fileId, {
    String? fileName,
    bool incrementOpen = true,
    int? viewDurationIncrement,
    int? mediaDuration,
  }) async {
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
            'increment_open': incrementOpen,
            if (viewDurationIncrement != null) 'view_duration_increment': viewDurationIncrement,
            if (mediaDuration != null) 'media_duration': mediaDuration,
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
      await _storeLocally(
        fileId,
        fileName: fileName,
        incrementOpen: incrementOpen,
        viewDurationIncrement: viewDurationIncrement,
        mediaDuration: mediaDuration,
      );
    } else {
      // Trigger silent sync of any previously stored offline logs
      syncPendingLogs();
    }
  }

  /// Store un-synced file access log locally.
  /// Duration updates CONSOLIDATE into the existing session record for the same
  /// file_id, so that one offline session produces exactly ONE pending log entry
  /// containing both the open flag and the final cumulative duration.
  static Future<void> _storeLocally(
    String fileId, {
    String? fileName,
    bool incrementOpen = true,
    int? viewDurationIncrement,
    int? mediaDuration,
  }) async {
    try {
      final String? existingJson = await AppStorage.read(_storageKey);
      List<dynamic> logs = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        logs = jsonDecode(existingJson) as List<dynamic>;
      }

      if (!incrementOpen && viewDurationIncrement != null) {
        // Duration update: find the LAST pending record for this file_id
        // and update it in-place instead of appending a new record.
        int lastIndex = -1;
        for (int i = logs.length - 1; i >= 0; i--) {
          if (logs[i]['file_id'].toString() == fileId) {
            lastIndex = i;
            break;
          }
        }

        if (lastIndex >= 0) {
          // Update existing record with the latest cumulative duration
          logs[lastIndex]['view_duration_increment'] = viewDurationIncrement;
          logs[lastIndex]['accessed_at'] = DateTime.now().toIso8601String();
          if (mediaDuration != null) {
            logs[lastIndex]['media_duration'] = mediaDuration;
          }
        } else {
          // No existing record for this file (edge case: open was already synced online).
          // Create a new record without increment_open so the server only updates duration.
          logs.add({
            'file_id': fileId,
            'file_name': fileName ?? 'File #$fileId',
            'accessed_at': DateTime.now().toIso8601String(),
            'increment_open': false,
            'view_duration_increment': viewDurationIncrement,
            if (mediaDuration != null) 'media_duration': mediaDuration,
          });
        }
      } else {
        // New open event — always append a new record to start a new session.
        logs.add({
          'file_id': fileId,
          'file_name': fileName ?? 'File #$fileId',
          'accessed_at': DateTime.now().toIso8601String(),
          'increment_open': incrementOpen,
          if (viewDurationIncrement != null) 'view_duration_increment': viewDurationIncrement,
          if (mediaDuration != null) 'media_duration': mediaDuration,
        });
      }

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
              'increment_open': log['increment_open'] ?? true,
              if (log['view_duration_increment'] != null) 'view_duration_increment': log['view_duration_increment'],
              if (log['media_duration'] != null) 'media_duration': log['media_duration'],
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
