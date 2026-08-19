import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/file_model.dart';
import 'auth_manager.dart';
import 'download/download_loader.dart';

class DownloadService {
  static const String _catalogFileName = 'offline_catalog.json';
  static final ValueNotifier<bool> isDownloadingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<double> downloadProgressNotifier = ValueNotifier<double>(0.0);
  static final ValueNotifier<String?> currentDownloadingFileNameNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<String?> downloadErrorNotifier = ValueNotifier<String?>(null);
  static VoidCallback? onCancelDownload;
  static final Set<String> _completedFileNames = {};
  static bool isCompletedInMemory(String fileName) => _completedFileNames.contains(fileName);

  static final ValueNotifier<Set<String>> activeDownloadsNotifier = ValueNotifier<Set<String>>({});
  static final Map<String, ValueNotifier<double>> progressNotifiers = {};
  static final Map<String, VoidCallback> onCancelDownloadMap = {};

  static ValueNotifier<double> getProgressNotifierFor(String fileName) {
    if (!progressNotifiers.containsKey(fileName)) {
      progressNotifiers[fileName] = ValueNotifier<double>(0.0);
    }
    return progressNotifiers[fileName]!;
  }

  static void cancelDownloadFor(String fileName) {
    if (onCancelDownloadMap.containsKey(fileName)) {
      onCancelDownloadMap[fileName]!();
      onCancelDownloadMap.remove(fileName);
    }
  }

  static void cancelDownload() {
    if (currentDownloadingFileNameNotifier.value != null) {
      cancelDownloadFor(currentDownloadingFileNameNotifier.value!);
    } else if (onCancelDownload != null) {
      onCancelDownload!();
    }
  }

  static Future<bool> downloadFile(String url, String fileName, {FileModel? model}) async {
    _completedFileNames.remove(fileName);
    
    // Add to active downloads
    activeDownloadsNotifier.value = {...activeDownloadsNotifier.value, fileName};
    isDownloadingNotifier.value = true;
    
    // Set current active for the header overlay
    currentDownloadingFileNameNotifier.value = fileName;
    
    final progressNotifier = getProgressNotifierFor(fileName);
    progressNotifier.value = 0.0;
    
    downloadErrorNotifier.value = null;

    if (!kIsWeb && model != null) {
      final startingModel = model.copyWith(
        isDownloaded: false,
        downloadProgress: 0.0,
        downloadStatus: 'downloading',
      );
      await saveOfflineMetadata(startingModel);
    }

    double lastSavedProgress = 0.0;

    try {
      final success = await startPlatformDownload(
        url,
        fileName,
        onProgress: (progress) async {
          progressNotifier.value = progress;
          if (!kIsWeb && model != null && (progress - lastSavedProgress).abs() >= 0.10) {
            lastSavedProgress = progress;
            final progressModel = model.copyWith(
              isDownloaded: false,
              downloadProgress: progress,
              downloadStatus: 'downloading',
            );
            await saveOfflineMetadata(progressModel);
          }
        },
      );

      if (success) {
        if (!kIsWeb && model != null) {
          final completedModel = model.copyWith(
            isDownloaded: true,
            downloadProgress: 1.0,
            downloadStatus: 'completed',
          );
          await saveOfflineMetadata(completedModel);
        }
        _completedFileNames.add(fileName);
        return true;
      } else {
        if (!kIsWeb && model != null) {
          final stoppedModel = model.copyWith(
            isDownloaded: false,
            downloadProgress: progressNotifier.value,
            downloadStatus: 'stopped',
          );
          await saveOfflineMetadata(stoppedModel);
        }
        return false;
      }
    } catch (e) {
      String errMsg = 'Unknown network error';
      if (e is SocketException) {
        errMsg = 'No internet connection or server unreachable (SocketException)';
      } else if (e is TimeoutException) {
        errMsg = 'Download timed out. The file might be too heavy or connection is too slow (TimeoutException)';
      } else if (e is HttpException) {
        errMsg = 'HTTP protocol error: ${e.message}';
      } else if (e.toString().contains('Software caused connection abort') || 
                 e.toString().contains('Connection reset') || 
                 e.toString().contains('Connection closed')) {
        errMsg = 'Connection lost. The file download was interrupted.';
      } else {
        errMsg = 'Network failure: $e';
      }
      downloadErrorNotifier.value = errMsg;

      if (!kIsWeb && model != null) {
        final failedModel = model.copyWith(
          isDownloaded: false,
          downloadProgress: progressNotifier.value,
          downloadStatus: 'stopped',
        );
        await saveOfflineMetadata(failedModel);
      }
      return false;
    } finally {
      // Remove from active downloads
      activeDownloadsNotifier.value = activeDownloadsNotifier.value.where((n) => n != fileName).toSet();
      isDownloadingNotifier.value = activeDownloadsNotifier.value.isNotEmpty;
      
      // Update header overlay current downloading file if needed
      if (currentDownloadingFileNameNotifier.value == fileName) {
        currentDownloadingFileNameNotifier.value = activeDownloadsNotifier.value.isNotEmpty 
            ? activeDownloadsNotifier.value.first 
            : null;
      }
      
      progressNotifier.value = 0.0;
    }
  }

  static Future<bool> isFileDownloaded(String fileName) async {
    if (kIsWeb) return false;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      if (!await file.exists()) return false;
      
      final catalogFile = await _getCatalogFile();
      if (!await catalogFile.exists()) return false;
      
      final content = await catalogFile.readAsString();
      if (content.isEmpty) return false;
      
      final List<dynamic> decoded = jsonDecode(content);
      for (var item in decoded) {
        if (item['name'] == fileName) {
          return item['downloadStatus'] == 'completed';
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getLocalFilePath(String fileName) async {
    if (kIsWeb) return null;
    try {
      if (await isFileDownloaded(fileName)) {
        final directory = await getApplicationDocumentsDirectory();
        return '${directory.path}/$fileName';
      }
    } catch (_) {}
    return null;
  }

  static Future<void> deleteDownloadedFile(String fileName) async {
    if (kIsWeb) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
      }
      await removeOfflineMetadataByFileName(fileName);
    } catch (_) {}
  }

  // --- LOCAL OFFLINE CATALOG MANAGEMENT ---

  static Future<File> _getCatalogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_catalogFileName');
  }

  static Future<void> saveOfflineMetadata(FileModel model) async {
    if (kIsWeb) return;
    try {
      final catalogFile = await _getCatalogFile();
      List<Map<String, dynamic>> items = [];

      if (await catalogFile.exists()) {
        final content = await catalogFile.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      // Remove existing item with same ID or name if present
      items.removeWhere((item) => item['id'] == model.id || item['name'] == model.name);

      // Add new item metadata
      items.add({
        'id': model.id,
        'name': model.name,
        'format': model.format,
        'sizeBytes': model.sizeBytes,
        'customSizeString': model.customSizeString,
        'uploadDate': model.uploadDate.toIso8601String(),
        'ownerName': model.ownerName,
        'previewUrl': model.previewUrl,
        'isPinned': model.isPinned,
        'isFavorite': model.isFavorite,
        'downloadProgress': model.downloadProgress,
        'downloadStatus': model.downloadStatus,
      });

      await catalogFile.writeAsString(jsonEncode(items));
    } catch (e) {
      debugPrint('Error saving offline metadata: $e');
    }
  }

  static Future<void> removeOfflineMetadataByFileName(String fileName) async {
    if (kIsWeb) return;
    try {
      final catalogFile = await _getCatalogFile();
      if (!await catalogFile.exists()) return;

      final content = await catalogFile.readAsString();
      if (content.isEmpty) return;

      final List<dynamic> decoded = jsonDecode(content);
      final List<Map<String, dynamic>> items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      items.removeWhere((item) => item['name'] == fileName);

      await catalogFile.writeAsString(jsonEncode(items));
    } catch (e) {
      debugPrint('Error removing offline metadata: $e');
    }
  }

  static Future<List<FileModel>> getOfflineFiles() async {
    if (kIsWeb) return [];
    final List<FileModel> results = [];
    try {
      final catalogFile = await _getCatalogFile();
      if (!await catalogFile.exists()) return [];

      final content = await catalogFile.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(content);
      final dir = await getApplicationDocumentsDirectory();

      for (var item in decoded) {
        final String name = item['name'] ?? 'Untitled';
        final fileOnDisk = File('${dir.path}/$name');
        final String status = item['downloadStatus'] ?? 'completed';
        double progress = (item['downloadProgress'] as num?)?.toDouble() ?? 1.0;

        String finalStatus = status;
        if (status == 'downloading') {
          if (currentDownloadingFileNameNotifier.value != name || !isDownloadingNotifier.value) {
            finalStatus = 'stopped';
          }
        }

        if (isDownloadingNotifier.value && currentDownloadingFileNameNotifier.value == name) {
          finalStatus = 'downloading';
          progress = downloadProgressNotifier.value;
        }

        bool isDownloaded = finalStatus == 'completed';

        if ((isDownloaded && await fileOnDisk.exists()) || !isDownloaded) {
          results.add(
            FileModel(
              id: item['id']?.toString() ?? name,
              name: name,
              format: item['format'] ?? 'doc',
              sizeBytes: (item['sizeBytes'] as int?) ?? (await fileOnDisk.exists() ? await fileOnDisk.length() : 0),
              customSizeString: item['customSizeString']?.toString(),
              uploadDate: DateTime.tryParse(item['uploadDate'] ?? '') ?? DateTime.now(),
              ownerName: item['ownerName'] ?? 'Downloaded',
              isPinned: item['isPinned'] ?? false,
              isFavorite: item['isFavorite'] ?? false,
              isDownloaded: isDownloaded,
              previewUrl: isDownloaded ? fileOnDisk.path : item['previewUrl'],
              downloadProgress: progress,
              downloadStatus: finalStatus,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting offline files: $e');
    }
    return results;
  }

  // --- ANALYTICS / ACCESS TRACKING ---

  static Future<void> trackFileAccess(
    String fileId, {
    int? completionPercentage,
    int? durationSeconds,
    int? mediaDuration,
    bool incrementOpen = true,
  }) async {
    if (AuthManager.token == null || AuthManager.token!.startsWith('google_token_')) return;
    try {
      final Map<String, dynamic> body = {
        'increment_open': incrementOpen,
      };
      if (completionPercentage != null) {
        body['completion_percentage'] = completionPercentage;
      }
      if (durationSeconds != null) {
        body['duration_seconds'] = durationSeconds;
      }
      if (mediaDuration != null) {
        body['media_duration'] = mediaDuration;
      }

      await http.post(
        Uri.parse('https://mindspacenlp.com/api/drive/file/$fileId/access'),
        headers: {
          'Authorization': 'Bearer ${AuthManager.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Silent catch — does not interrupt user experience if offline or network fails
    }
  }
}
