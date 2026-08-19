import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/mock_data.dart';
import '../models/file_model.dart';
import '../widgets/buttons.dart';
import '../services/role_manager.dart';
import '../services/offline_access_tracker.dart';
import '../services/download_service.dart';
import 'preview/file_previewer_page.dart';
import '../widgets/platform_preview/preview_loader.dart';
import '../widgets/rotating_vinyl.dart';
import '../services/recent_service.dart';
import '../widgets/custom_audio_player.dart';
import '../widgets/custom_video_player.dart';
import '../widgets/app_toast.dart';

class FileDetailsPage extends StatefulWidget {
  final FileModel file;

  const FileDetailsPage({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  State<FileDetailsPage> createState() => _FileDetailsPageState();
}

class _FileDetailsPageState extends State<FileDetailsPage> {
  late bool _isFavorite;
  late bool _isDownloaded;
  late String _fileName;
  Duration _mediaPosition = Duration.zero;
  bool _mediaIsPlaying = false;
  bool _isFullscreenOpen = false;
  String? _activePath;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _isFavorite = widget.file.isFavorite;
    _isDownloaded = widget.file.isDownloaded;
    _fileName = widget.file.name;
    _activePath = widget.file.previewUrl;
    _checkOfflineStatus();
    RecentService.addFileToRecent(widget.file);
    OfflineAccessTracker.trackAccess(widget.file.id, fileName: widget.file.name);
  }

  @override
  void dispose() {
    final durationSeconds = DateTime.now().difference(_startTime).inSeconds;
    DownloadService.trackFileAccess(widget.file.id, durationSeconds: durationSeconds, incrementOpen: false);
    super.dispose();
  }

  Future<void> _checkOfflineStatus() async {
    final downloaded = await DownloadService.isFileDownloaded(_fileName);
    final localPath = await DownloadService.getLocalFilePath(_fileName);
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
        if (downloaded && localPath != null) {
          _activePath = localPath;
        } else {
          _activePath = widget.file.previewUrl;
        }
      });
    }
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    // Update in Master Mock List
    final idx = MockData.files.indexWhere((f) => f.id == widget.file.id);
    if (idx != -1) {
      MockData.files[idx] = FileModel(
        id: widget.file.id,
        name: _fileName,
        format: widget.file.format,
        sizeBytes: widget.file.sizeBytes,
        uploadDate: widget.file.uploadDate,
        ownerName: widget.file.ownerName,
        isPinned: widget.file.isPinned,
        isFavorite: _isFavorite,
        isDownloaded: _isDownloaded,
        previewUrl: widget.file.previewUrl,
      );
    }

    // TODO: API Integration Here - Laravel REST API toggle favorite endpoint.
    AppToast.showInfo(context, _isFavorite ? 'Added to favorites.' : 'Removed from favorites.');
  }

  bool _isDownloadingThis = false;

  void _toggleDownload() async {
    final previewUrl = widget.file.previewUrl;
    if (!_isDownloaded) {
      if (previewUrl != null && previewUrl.isNotEmpty) {
        setState(() {
          _isDownloadingThis = true;
        });

        AppToast.showInfo(context, 'Saving "$_fileName" offline in background...');
        final success = await DownloadService.downloadFile(previewUrl, _fileName, model: widget.file);

        if (mounted) {
          setState(() {
            _isDownloadingThis = false;
          });
        }

        if (!success) {
          if (mounted) {
            final error = DownloadService.downloadErrorNotifier.value ?? 'Download failed. Please check internet connection.';
            AppToast.showError(context, error);
          }
          return;
        }
      }
    } else {
      await DownloadService.deleteDownloadedFile(_fileName);
    }

    setState(() {
      _isDownloaded = !_isDownloaded;
    });

    await _checkOfflineStatus();

    final idx = MockData.files.indexWhere((f) => f.id == widget.file.id);
    if (idx != -1) {
      MockData.files[idx] = FileModel(
        id: widget.file.id,
        name: _fileName,
        format: widget.file.format,
        sizeBytes: widget.file.sizeBytes,
        uploadDate: widget.file.uploadDate,
        ownerName: widget.file.ownerName,
        isPinned: widget.file.isPinned,
        isFavorite: _isFavorite,
        isDownloaded: _isDownloaded,
        previewUrl: widget.file.previewUrl,
      );
    }

    if (mounted) {
      if (_isDownloaded) {
        AppToast.showSuccess(context, 'File saved locally for offline access!');
      } else {
        AppToast.showInfo(context, 'Removed from offline storage.');
      }
    }
  }

  void _handleRename() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final renameController = TextEditingController(text: _fileName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Rename File', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: renameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'New Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () {
                final newName = renameController.text.trim();
                if (newName.isNotEmpty) {
                  setState(() {
                    _fileName = newName;
                  });
                  final idx = MockData.files.indexWhere((f) => f.id == widget.file.id);
                  if (idx != -1) {
                    MockData.files[idx] = FileModel(
                      id: widget.file.id,
                      name: newName,
                      format: widget.file.format,
                      sizeBytes: widget.file.sizeBytes,
                      uploadDate: widget.file.uploadDate,
                      ownerName: widget.file.ownerName,
                      isPinned: widget.file.isPinned,
                      isFavorite: _isFavorite,
                      isDownloaded: _isDownloaded,
                      previewUrl: widget.file.previewUrl,
                    );
                  }
                  // TODO: API Integration Here - Laravel REST API rename endpoint.
                }
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _handleDelete() {
    // Confirm delete
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete File', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to permanently delete "$_fileName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                MockData.files.removeWhere((f) => f.id == widget.file.id);
                // TODO: API Integration Here - Laravel REST API delete endpoint.
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$_fileName" deleted successfully.')),
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.file.isFolder ? 'Folder Details' : 'File Details',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _isFavorite ? AppColors.warning : (isDark ? Colors.white70 : Colors.black54),
            ),
            onPressed: _toggleFavorite,
          ),
          if (RoleManager.isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: _handleRename,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              onPressed: _handleDelete,
            ),
          ],
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Large Preview Box
              _buildLargePreview(context),
              const SizedBox(height: 28),

              // File Name Block
              Text(
                _fileName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.file.isFolder ? 'Directory Folder' : '${widget.file.format.toUpperCase()} Document',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Main CTA Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    text: widget.file.isFolder ? 'Open Folder' : 'Open / View File',
                    icon: widget.file.isFolder ? Icons.folder_open_rounded : Icons.visibility_rounded,
                    onPressed: () async {
                      if (widget.file.isFolder) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Folder navigation triggered (UI only)')),
                        );
                      } else {
                        final wasPlaying = _mediaIsPlaying;
                        setState(() {
                          _isFullscreenOpen = true;
                        });
                        final result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FilePreviewerPage(
                              file: widget.file,
                              initialPosition: _mediaPosition,
                              autoPlay: wasPlaying,
                            ),
                          ),
                        );
                        if (mounted) {
                          setState(() {
                            _isFullscreenOpen = false;
                            if (result != null) {
                              _mediaPosition = result['position'] as Duration? ?? Duration.zero;
                              _mediaIsPlaying = result['isPlaying'] as bool? ?? false;
                            }
                          });
                        }
                      }
                    },
                  ),
                  if (!widget.file.isFolder) ...[
                    const SizedBox(height: 16),
                    _isDownloaded
                        ? DangerButton(
                            text: 'Delete Offline File',
                            icon: Icons.delete_outline_rounded,
                            onPressed: _toggleDownload,
                          )
                        : SecondaryButton(
                            text: _isDownloadingThis ? 'Saving Offline...' : 'Save Offline',
                            icon: Icons.download_rounded,
                            isLoading: _isDownloadingThis,
                            onPressed: _toggleDownload,
                          ),
                  ],
                ],
              ),
              const SizedBox(height: 40),

              // File Information Table
              Text(
                'Properties',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Owner', widget.file.ownerName, Icons.person_outline_rounded),
                    const Divider(height: 24),
                    _buildInfoRow(
                      'Created Date',
                      _formatFullDate(widget.file.uploadDate),
                      Icons.calendar_today_rounded,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      'File Size',
                      widget.file.isFolder ? '--' : widget.file.sizeString,
                      Icons.data_usage_rounded,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      'Location',
                      widget.file.isFolder ? 'My Drive' : 'My Drive > ${_fileName.split('.').last.toUpperCase()}s',
                      Icons.folder_open_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargePreview(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasUrl = widget.file.previewUrl != null && widget.file.previewUrl!.isNotEmpty;
    final useHero = !hasUrl || widget.file.isFolder;

    final previewBox = Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _buildPreviewContent(context),
      ),
    );

    if (useHero) {
      return Hero(
        tag: 'hero-icon-${widget.file.id}',
        child: Material(
          color: Colors.transparent,
          child: previewBox,
        ),
      );
    }

    return previewBox;
  }

  Widget _buildPreviewContent(BuildContext context) {
    if (_isFullscreenOpen) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }

    final theme = Theme.of(context);
    final url = _activePath;
    final hasUrl = url != null && url.isNotEmpty;

    if (widget.file.format == 'folder') {
      return _buildPreviewIcon(Icons.folder_rounded, Colors.amber.shade600);
    }

    final format = widget.file.format.toLowerCase();

    if (format == 'pdf') {
      return hasUrl 
          ? buildPlatformPdf(url) 
          : _buildPreviewIcon(Icons.picture_as_pdf_rounded, AppColors.error);
    }
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'image'].contains(format)) {
      return hasUrl
          ? buildPlatformImage(url)
          : _buildPreviewIcon(Icons.image_rounded, AppColors.info);
    }
    if (format == 'mp3' || format == 'audio' || format == 'wav') {
      return hasUrl
          ? CustomAudioPlayer(
              url: url,
              fileName: widget.file.name,
              isMini: true,
              initialPosition: _mediaPosition,
              autoPlay: _mediaIsPlaying,
              onPositionChanged: (pos) {
                _mediaPosition = pos;
              },
              onPlayingChanged: (playing) {
                _mediaIsPlaying = playing;
              },
            )
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RotatingVinyl(size: 90),
                  SizedBox(height: 12),
                  Text(
                    'Offline Audio Track',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
    }
    if (format == 'video' || format == 'mp4' || format == 'mov') {
      return hasUrl
          ? CustomVideoPlayer(
              url: url,
              fileName: widget.file.name,
              isMini: true,
              initialPosition: _mediaPosition,
              autoPlay: _mediaIsPlaying,
              onPositionChanged: (pos) {
                _mediaPosition = pos;
              },
              onPlayingChanged: (playing) {
                _mediaIsPlaying = playing;
              },
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                _buildPreviewIcon(Icons.video_library_rounded, AppColors.secondary),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ],
            );
    }
    if (format == 'doc') {
      return _buildPreviewIcon(Icons.description_rounded, AppColors.primary);
    }

    return _buildPreviewIcon(Icons.insert_drive_file_rounded, Colors.grey);
  }

  Widget _buildPreviewIcon(IconData icon, Color color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 64,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${_formatTime(date)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = date.minute < 10 ? '0${date.minute}' : '${date.minute}';
    return '$hour:$minuteStr $ampm';
  }
}

