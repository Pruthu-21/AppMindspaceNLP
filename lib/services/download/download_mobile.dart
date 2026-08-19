import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../download_service.dart';

Future<bool> startPlatformDownload(String url, String fileName, {Function(double progress)? onProgress}) async {
  IOSink? sink;
  HttpClient? client;
  HttpClientRequest? request;
  
  try {
    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    
    int existingBytes = 0;
    bool isResume = false;
    
    // Check if we can resume: file exists and was not marked completed
    final isCompleted = await DownloadService.isFileDownloaded(fileName);
    if (file.existsSync() && !isCompleted) {
      existingBytes = file.lengthSync();
      if (existingBytes > 0) {
        isResume = true;
      }
    }

    final uri = Uri.parse(url);
    request = await client.getUrl(uri);
    
    if (isResume) {
      request.headers.add('Range', 'bytes=$existingBytes-');
    }

    // Register cancellation hook
    DownloadService.onCancelDownloadMap[fileName] = () {
      try {
        request?.abort();
      } catch (_) {}
      try {
        client?.close(force: true);
      } catch (_) {}
    };

    final response = await request.close();

    if (response.statusCode == 206 || (isResume && response.statusCode == 200)) {
      // If server returned 206, we append. If 200, we overwrite from scratch.
      final actualResume = response.statusCode == 206;
      final int totalContentLength = response.contentLength;
      
      int totalBytes;
      if (actualResume) {
        totalBytes = existingBytes + totalContentLength;
        sink = file.openWrite(mode: FileMode.append);
      } else {
        totalBytes = totalContentLength;
        sink = file.openWrite(mode: FileMode.write);
      }
      
      int downloaded = actualResume ? existingBytes : 0;

      // Read chunks from response stream
      await for (var chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(downloaded / totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (totalBytes > 0 && downloaded < totalBytes) {
        throw HttpException('Download was cut off early. Received $downloaded of $totalBytes bytes.');
      }
      
      if (onProgress != null) onProgress(1.0);
      return true;
    } else if (response.statusCode == 200) {
      // Standard non-resume download
      final totalBytes = response.contentLength;
      sink = file.openWrite(mode: FileMode.write);
      int downloaded = 0;

      await for (var chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(downloaded / totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (totalBytes > 0 && downloaded < totalBytes) {
        throw HttpException('Download was cut off early. Received $downloaded of $totalBytes bytes.');
      }
      
      if (onProgress != null) onProgress(1.0);
      return true;
    } else {
      throw HttpException('Server returned status code ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Download failed: $e');
    if (sink != null) {
      try {
        await sink.close();
      } catch (_) {}
    }
    rethrow;
  } finally {
    client?.close();
    DownloadService.onCancelDownloadMap.remove(fileName);
  }
}
