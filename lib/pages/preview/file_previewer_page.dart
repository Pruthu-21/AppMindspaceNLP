import 'package:flutter/material.dart';
import '../../models/file_model.dart';
import '../../widgets/platform_preview/preview_loader.dart';
import 'package:url_launcher/url_launcher.dart';
import '../reviews_page.dart'; // Just checking if it exists, or maybe we don't need the review sheet right away in the previewer
import '../../widgets/custom_audio_player.dart';
import '../../widgets/custom_video_player.dart';

class FilePreviewerPage extends StatefulWidget {
  final dynamic file; // Actually FileModel, using dynamic because type check issue might happen if imported wrongly
  final Duration? initialPosition;
  final bool autoPlay;

  const FilePreviewerPage({
    super.key,
    required this.file,
    this.initialPosition,
    this.autoPlay = false,
  });

  @override
  State<FilePreviewerPage> createState() => _FilePreviewerPageState();
}

class _FilePreviewerPageState extends State<FilePreviewerPage> {
  Future<void> _openExternally(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open file externally"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Attempt cast to FileModel
    final file = widget.file;
    final String url = (file is FileModel) ? (file.previewUrl ?? '') : '';
    final String name = (file is FileModel) ? file.name : 'Unknown';
    final String format = (file is FileModel) ? file.format : 'doc';
    final int fileId = (file is FileModel) ? int.tryParse(file.id) ?? 0 : 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: _buildContent(format, url, name, fileId),
      ),
    );
  }

  Widget _buildContent(String format, String url, String name, int fileId) {
    if (url.isEmpty) {
      return const Text("No preview URL available", style: TextStyle(color: Colors.white70));
    }

    if (format == 'pdf') {
      return buildPlatformPdf(url);
    } else if (format == 'mp4' || format == 'video' || format == 'mov') {
      return CustomVideoPlayer(
        url: url,
        fileName: name,
        fileId: fileId > 0 ? fileId.toString() : null,
        initialPosition: widget.initialPosition ?? Duration.zero,
        autoPlay: widget.autoPlay,
      );
    } else if (format == 'mp3' || format == 'audio' || format == 'wav') {
      return CustomAudioPlayer(
        url: url,
        fileName: name,
        fileId: fileId > 0 ? fileId.toString() : null,
        initialPosition: widget.initialPosition ?? Duration.zero,
        autoPlay: widget.autoPlay,
      );
    } else if (format == 'png' || format == 'jpg') {
      return buildPlatformImage(url);
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            "Preview not available natively.",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openExternally(url),
            icon: const Icon(Icons.open_in_new),
            label: const Text("Open in External App"),
          ),
        ],
      );
    }
  }
}
