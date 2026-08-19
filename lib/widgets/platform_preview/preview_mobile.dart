import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

Widget buildPlatformVideo(String url) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.video_library_rounded, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('Video Player Placeholder'),
        const SizedBox(height: 8),
        Text(url, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    ),
  );
}

Widget buildPlatformPdf(String url) {
  final isNetwork = url.startsWith('http://') || url.startsWith('https://');
  if (isNetwork) {
    return NativePdfViewer(url: url, isNetwork: true);
  } else {
    return NativePdfViewer(url: url, isNetwork: false);
  }
}

Widget buildPlatformAudio(String url) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.audiotrack_rounded, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('Audio Player Placeholder'),
        const SizedBox(height: 8),
        Text(url, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    ),
  );
}

Widget buildPlatformImage(String url) {
  final isNetwork = url.startsWith('http://') || url.startsWith('https://');
  if (isNetwork) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Failed to load image', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      },
    );
  } else {
    return Image.file(
      File(url),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Failed to load offline image', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }
}

/// Unified PDF viewer for both online (downloads then renders) and offline local files.
/// Always uses pdfx with vertical scrolling - consistent UI for all PDFs.
class NativePdfViewer extends StatefulWidget {
  final String url;
  final bool isNetwork;
  const NativePdfViewer({Key? key, required this.url, required this.isNetwork}) : super(key: key);

  @override
  State<NativePdfViewer> createState() => _NativePdfViewerState();
}

class _NativePdfViewerState extends State<NativePdfViewer> {
  PdfController? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      final controller = PdfController(
        document: widget.isNetwork
            ? PdfDocument.openData(_fetchNetworkBytes(widget.url))
            : PdfDocument.openFile(widget.url),
      );
      if (mounted) {
        setState(() {
          _pdfController = controller;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load PDF. Please try again.';
        });
      }
    }
  }

  Future<Uint8List> _fetchNetworkBytes(String url) async {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse(url));
    final response = await request.close();
    final bytes = await response.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
    return Uint8List.fromList(bytes);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white70),
              SizedBox(height: 16),
              Text(
                'Loading PDF...',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return PdfView(
      controller: _pdfController!,
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
    );
  }
}
