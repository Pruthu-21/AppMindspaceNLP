import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:background_downloader/background_downloader.dart';
import '../download_service.dart';

Future<bool> startPlatformDownload(String url, String fileName, {Function(double progress)? onProgress}) async {
  try {
    // Configure notifications for all downloads
    FileDownloader().configureNotification(
      running: const TaskNotification('Mind Space', 'Downloading {filename}'),
      complete: const TaskNotification('Mind Space', 'Download complete\n{filename}'),
      error: const TaskNotification('Mind Space', 'Download failed\n{filename}'),
      paused: const TaskNotification('Mind Space', 'Download paused\n{filename}'),
      progressBar: true,
      tapOpensFile: true,
    );

    // Define the download task
    final task = DownloadTask(
      taskId: fileName,
      url: url,
      filename: fileName,
      baseDirectory: BaseDirectory.applicationDocuments, // Use stable relative directory
      updates: Updates.statusAndProgress,
      allowPause: true,
      requiresWiFi: false,
      retries: 3,
    );
    debugPrint('MSNLP_DOWNLOAD | START taskId=${task.taskId}');

    // Register cancellation hook
    DownloadService.onCancelDownloadMap[fileName] = () {
      FileDownloader().cancelTaskWithId(task.taskId);
    };

    bool success = false;
    double lastReportedProgress = 0.0;
    double highestProgressSeen = 0.0;
    bool wasWaitingToRetry = false;
    
    Timer? networkTimer;
    bool isNetworkLostState = false;

    Future<bool> checkInternet() async {
      if (kIsWeb) return true;
      try {
        final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    // Execute the download and listen to updates
    debugPrint('MSNLP_BACKGROUND | STARTED taskId=${task.taskId}');
    
    networkTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      final hasInternet = await checkInternet();
      if (!hasInternet && !isNetworkLostState) {
        isNetworkLostState = true;
        debugPrint('MSNLP_DOWNLOAD | NETWORK_LOST taskId=${task.taskId} fileId=$fileName');
        await FileDownloader().pause(task);
      } else if (hasInternet && isNetworkLostState) {
        isNetworkLostState = false;
        debugPrint('MSNLP_DOWNLOAD | NETWORK_RESTORED taskId=${task.taskId}');
        debugPrint('MSNLP_DOWNLOAD | RESUME taskId=${task.taskId}');
        await FileDownloader().resume(task);
      }
    });

    final result = await FileDownloader().download(
      task,
      onProgress: (progress) {
        final timestamp = DateTime.now().toIso8601String();
        debugPrint('MSNLP_DOWNLOAD | RAW_PROGRESS taskId=${task.taskId} progress=$progress timestamp=$timestamp');
        
        // progress is between 0.0 and 1.0 (or negative for special states)
        if (progress >= 0.0 && progress <= 1.0) {
          if (progress < highestProgressSeen) {
            debugPrint('MSNLP_DOWNLOAD | PROGRESS_REGRESSION taskId=${task.taskId} previous=$highestProgressSeen current=$progress');
            // Protect UI from stale callbacks: do not process regressed progress
            return;
          }
          debugPrint('MSNLP_DOWNLOAD | STATE_PROGRESS taskId=${task.taskId} previous=$highestProgressSeen new=$progress timestamp=$timestamp');
          highestProgressSeen = progress;

          if (progress == 0.0) debugPrint('MSNLP_NOTIFICATION | CREATED taskId=${task.taskId}');
          // Avoid flooding the stream, only report every 5%
          if (progress == 1.0 || (progress - lastReportedProgress).abs() >= 0.05) {
            lastReportedProgress = progress;
            if (onProgress != null) onProgress(progress);
            debugPrint('MSNLP_DOWNLOAD | PROGRESS taskId=${task.taskId} percentage=${(progress * 100).toStringAsFixed(1)}%');
            debugPrint('MSNLP_NOTIFICATION | PROGRESS taskId=${task.taskId} percentage=${(progress * 100).toStringAsFixed(1)}%');
          }
        } else if (progress == -1.0) {
           debugPrint('MSNLP_ERROR | NETWORK_LOST taskId=${task.taskId}');
        } else if (progress == -3.0) { // Failed
           debugPrint('MSNLP_DOWNLOAD | FAILED taskId=${task.taskId}');
        } else if (progress == -4.0) { // Canceled
           debugPrint('MSNLP_DOWNLOAD | CANCELLED taskId=${task.taskId}');
        }
      },
      onStatus: (status) {
        debugPrint('MSNLP_DOWNLOAD | STATE_CHANGE taskId=${task.taskId} state=${status.name}');
        if (status == TaskStatus.running) {
          if (wasWaitingToRetry) {
             debugPrint('MSNLP_DOWNLOAD | NETWORK_RESTORED taskId=${task.taskId}');
             debugPrint('MSNLP_DOWNLOAD | RESUMING taskId=${task.taskId}');
             wasWaitingToRetry = false;
          }
          debugPrint('MSNLP_DOWNLOAD | RESUMED taskId=${task.taskId}');
        } else if (status == TaskStatus.complete) {
          success = true;
          debugPrint('MSNLP_NOTIFICATION | COMPLETED taskId=${task.taskId}');
          if (onProgress != null) onProgress(1.0);
        } else if (status == TaskStatus.canceled) {
          success = false;
          debugPrint('MSNLP_DOWNLOAD | CANCELLED taskId=${task.taskId}');
        } else if (status == TaskStatus.failed || status == TaskStatus.notFound) {
          success = false;
          debugPrint('MSNLP_DOWNLOAD | FAILED taskId=${task.taskId} state=${status.name}');
          debugPrint('MSNLP_NOTIFICATION | FAILED taskId=${task.taskId}');
        } else if (status == TaskStatus.paused) {
          debugPrint('MSNLP_DOWNLOAD | PAUSED taskId=${task.taskId}');
        } else if (status == TaskStatus.waitingToRetry) {
          wasWaitingToRetry = true;
          debugPrint('MSNLP_DOWNLOAD | NETWORK_LOST taskId=${task.taskId}');
          debugPrint('MSNLP_DOWNLOAD | PAUSED_NETWORK taskId=${task.taskId}');
          debugPrint('MSNLP_DOWNLOAD | RETRYING taskId=${task.taskId}');
        }
      },
    );

    if (result.status == TaskStatus.complete) {
      final actualPath = await task.filePath();
      final file = File(actualPath);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      debugPrint('MSNLP_DOWNLOAD | COMPLETED taskId=${task.taskId}');
      debugPrint('MSNLP_FILE | VERIFY fileId=$fileName exists=$exists size=$size expectedPath=$actualPath readable=$exists');
      if (!exists) {
        debugPrint('DOWNLOAD_REPORTED_COMPLETE_BUT_FILE_MISSING');
      }
      return true;
    } else {
      throw HttpException('Download failed with status: ${result.status.name}');
    }
  } catch (e) {
    debugPrint('[DOWNLOAD_DEBUG] PAUSED/FAILED Error: $e');
    rethrow;
  } finally {
    networkTimer?.cancel();
    DownloadService.onCancelDownloadMap.remove(fileName);
  }
}
