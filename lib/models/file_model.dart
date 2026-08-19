class FileModel {
  final String id;
  final String name;
  final String format; // 'pdf', 'image', 'video', 'audio', 'doc', 'folder', etc.
  final int sizeBytes;
  final String? customSizeString;
  final DateTime uploadDate;
  final String ownerName;
  final bool isPinned;
  final bool isFavorite;
  final bool isDownloaded;
  final String? previewUrl;
  final double downloadProgress; // 0.0 to 1.0
  final String downloadStatus; // 'completed', 'downloading', 'stopped'

  FileModel({
    required this.id,
    required this.name,
    required this.format,
    required this.sizeBytes,
    this.customSizeString,
    required this.uploadDate,
    required this.ownerName,
    this.isPinned = false,
    this.isFavorite = false,
    this.isDownloaded = false,
    this.previewUrl,
    this.downloadProgress = 1.0,
    this.downloadStatus = 'completed',
  });

  static int parseSizeStringToBytes(String? sizeStr) {
    if (sizeStr == null || sizeStr.isEmpty) return 0;
    try {
      final clean = sizeStr.trim().toUpperCase();
      final match = RegExp(r'^([\d\.]+)\s*(B|KB|MB|GB|TB)?$').firstMatch(clean);
      if (match == null) return 0;
      
      final numVal = double.tryParse(match.group(1) ?? '') ?? 0.0;
      final unit = match.group(2);
      
      if (unit == 'KB') return (numVal * 1024).toInt();
      if (unit == 'MB') return (numVal * 1024 * 1024).toInt();
      if (unit == 'GB') return (numVal * 1024 * 1024 * 1024).toInt();
      if (unit == 'TB') return (numVal * 1024 * 1024 * 1024 * 1024).toInt();
      return numVal.toInt();
    } catch (_) {
      return 0;
    }
  }

  static String detectFormat(String name, String? mimeType, bool isFolder) {
    if (isFolder) return 'folder';
    
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.contains('pdf')) return 'pdf';
    if (mime.contains('audio') || mime.contains('mp3') || mime.contains('wav')) return 'mp3';
    if (mime.contains('video') || mime.contains('mp4') || mime.contains('mov')) return 'mp4';
    if (mime.contains('presentation') || mime.contains('ppt')) return 'ppt';
    if (mime.contains('image') || mime.contains('png') || mime.contains('jpg') || mime.contains('jpeg')) return 'png';
    
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (['pdf'].contains(ext)) return 'pdf';
    if (['mp3', 'wav', 'ogg', 'm4a', 'flac', 'aac'].contains(ext)) return 'mp3';
    if (['mp4', 'mov', 'mkv', 'webm', 'avi', 'flv', 'wmv'].contains(ext)) return 'mp4';
    if (['ppt', 'pptx'].contains(ext)) return 'ppt';
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) return 'png';
    
    return 'doc';
  }

  String get sizeString {
    if (format == 'folder') return '--';
    if (customSizeString != null && customSizeString!.isNotEmpty) return customSizeString!;
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool get isFolder => format == 'folder';

  FileModel copyWith({
    String? id,
    String? name,
    String? format,
    int? sizeBytes,
    String? customSizeString,
    DateTime? uploadDate,
    String? ownerName,
    bool? isPinned,
    bool? isFavorite,
    bool? isDownloaded,
    String? previewUrl,
    double? downloadProgress,
    String? downloadStatus,
  }) {
    return FileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      format: format ?? this.format,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      customSizeString: customSizeString ?? this.customSizeString,
      uploadDate: uploadDate ?? this.uploadDate,
      ownerName: ownerName ?? this.ownerName,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      previewUrl: previewUrl ?? this.previewUrl,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadStatus: downloadStatus ?? this.downloadStatus,
    );
  }
}
