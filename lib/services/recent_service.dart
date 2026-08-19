import 'dart:convert';
import 'app_storage.dart';
import '../models/file_model.dart';

class RecentService {
  static const String _storageKey = 'recent_files_list';

  static Future<List<FileModel>> getRecentFiles() async {
    try {
      final jsonStr = await AppStorage.read(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((item) {
          return FileModel(
            id: item['id']?.toString() ?? '',
            name: item['name'] ?? 'Untitled',
            format: item['format'] ?? 'doc',
            sizeBytes: item['sizeBytes'] ?? 0,
            customSizeString: item['customSizeString'],
            uploadDate: DateTime.tryParse(item['uploadDate'] ?? '') ?? DateTime.now(),
            ownerName: item['ownerName'] ?? 'Unknown',
            isPinned: item['isPinned'] == true,
            isFavorite: item['isFavorite'] == true,
            isDownloaded: item['isDownloaded'] == true,
            previewUrl: item['previewUrl'],
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> addFileToRecent(FileModel file) async {
    if (file.isFolder) return;
    try {
      final currentList = await getRecentFiles();
      
      // Remove if already exists to push to top of stack
      currentList.removeWhere((f) => f.id == file.id);
      
      // Insert at index 0 (newest recent)
      currentList.insert(0, file);
      
      // Limit size of recent stack to 20 files
      if (currentList.length > 20) {
        currentList.removeLast();
      }
      
      // Serialize list
      final serialized = currentList.map((f) => {
        'id': f.id,
        'name': f.name,
        'format': f.format,
        'sizeBytes': f.sizeBytes,
        'customSizeString': f.customSizeString,
        'uploadDate': f.uploadDate.toIso8601String(),
        'ownerName': f.ownerName,
        'isPinned': f.isPinned,
        'isFavorite': f.isFavorite,
        'isDownloaded': f.isDownloaded,
        'previewUrl': f.previewUrl,
      }).toList();
      
      await AppStorage.write(_storageKey, jsonEncode(serialized));
    } catch (_) {}
  }
}
