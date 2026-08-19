import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/mock_data.dart';
import '../models/file_model.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/file_card.dart';
import '../widgets/empty_widget.dart';
import 'file_details_page.dart';
import 'preview/file_previewer_page.dart';
import '../services/download_service.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({Key? key}) : super(key: key);

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  bool _isGridView = false;
  String _searchQuery = '';
  List<FileModel> _offlineFiles = [];

  @override
  void initState() {
    super.initState();
    _loadOfflineFiles();
    DownloadService.isDownloadingNotifier.addListener(_onDownloadChanged);
  }

  @override
  void dispose() {
    DownloadService.isDownloadingNotifier.removeListener(_onDownloadChanged);
    super.dispose();
  }

  void _onDownloadChanged() {
    _loadOfflineFiles();
  }

  String _activeCategoryFilter = 'All';

  void _loadOfflineFiles() async {
    List<FileModel> offline = await DownloadService.getOfflineFiles();

    if (_activeCategoryFilter != 'All') {
      if (_activeCategoryFilter == 'PDFs') {
        offline = offline.where((f) => f.format.toLowerCase() == 'pdf').toList();
      } else if (_activeCategoryFilter == 'Images') {
        offline = offline.where((f) => ['png', 'jpg', 'jpeg', 'gif', 'webp', 'image'].contains(f.format.toLowerCase())).toList();
      } else if (_activeCategoryFilter == 'Videos') {
        offline = offline.where((f) => ['mp4', 'video', 'mov'].contains(f.format.toLowerCase())).toList();
      } else if (_activeCategoryFilter == 'Docs') {
        offline = offline.where((f) => ['doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'].contains(f.format.toLowerCase())).toList();
      }
    }

    if (_searchQuery.trim().isNotEmpty) {
      offline = offline
          .where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (mounted) {
      setState(() {
        _offlineFiles = offline;
      });
    }
  }

  int _calculateOfflineStorage() {
    int total = 0;
    for (var f in _offlineFiles) {
      total += f.sizeBytes;
    }
    return total;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _handleRemoveOffline(FileModel file) async {
    await DownloadService.deleteDownloadedFile(file.name);
    _loadOfflineFiles();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${file.name}" from offline access.')),
      );
    }
  }

  void _handleResumeDownload(FileModel file) async {
    final url = file.previewUrl;
    if (url != null && url.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resuming download for "${file.name}"...')),
      );
      final success = await DownloadService.downloadFile(url, file.name, model: file);
      if (!success && mounted) {
        final error = DownloadService.downloadErrorNotifier.value ?? 'Download failed. Please check internet connection.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      _loadOfflineFiles();
    }
  }

  void _showFilterSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Filter Offline Files',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'PDFs', 'Images', 'Videos', 'Docs'].map((cat) {
                      final isSelected = _activeCategoryFilter == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _activeCategoryFilter = cat;
                              _loadOfflineFiles();
                            });
                            setSheetState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalSizeStr = _formatSize(_calculateOfflineStorage());

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Offline Files',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Offline Space Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  border: Border.all(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.offline_pin_rounded,
                        color: AppColors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline Storage Used',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_offlineFiles.length} file(s) downloaded ($totalSizeStr stored locally)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar
              SearchBarWidget(
                hintText: 'Search offline files',
                onChanged: (val) {
                  _searchQuery = val;
                  _loadOfflineFiles();
                },
                onFilterPressed: _showFilterSheet,
              ),
              const SizedBox(height: 16),

              // Files display
              Expanded(
                child: _offlineFiles.isEmpty
                    ? const EmptyWidget(
                        icon: Icons.cloud_off_rounded,
                        title: 'No Offline Files',
                        description:
                            'Files you designate as "Make Offline" will appear here for access when you don\'t have a network connection.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          // TODO: API Integration Here
                          await Future.delayed(const Duration(seconds: 1));
                        },
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 100),
                          child: _isGridView
                              ? GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _offlineFiles.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final file = _offlineFiles[index];
                                    return FileCard(
                                      file: file,
                                      isGrid: true,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FileDetailsPage(file: file),
                                          ),
                                        );
                                      },
                                      onMenuSelected: (action) {
                                        if (action == 'download') {
                                          if (file.downloadStatus == 'stopped') {
                                            _handleResumeDownload(file);
                                          } else {
                                            _handleRemoveOffline(file);
                                          }
                                        } else if (action == 'remove_partial') {
                                          _handleRemoveOffline(file);
                                        }
                                      },
                                    );
                                  },
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _offlineFiles.length,
                                  itemBuilder: (context, index) {
                                    final file = _offlineFiles[index];
                                    return FileCard(
                                      file: file,
                                      isGrid: false,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FileDetailsPage(file: file),
                                          ),
                                        );
                                      },
                                      onMenuSelected: (action) {
                                        if (action == 'download') {
                                          if (file.downloadStatus == 'stopped') {
                                            _handleResumeDownload(file);
                                          } else {
                                            _handleRemoveOffline(file);
                                          }
                                        } else if (action == 'remove_partial') {
                                          _handleRemoveOffline(file);
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
