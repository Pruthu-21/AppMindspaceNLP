import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';
import '../models/file_model.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/file_card.dart';
import '../widgets/empty_widget.dart';
import '../services/recent_service.dart';
import '../services/download_service.dart';
import '../services/auth_manager.dart';
import '../widgets/app_toast.dart';
import 'file_details_page.dart';

class RecentPage extends StatefulWidget {
  const RecentPage({Key? key}) : super(key: key);

  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  bool _isGridView = false;
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'PDFs', 'Images', 'Videos', 'Docs'
  List<FileModel> _recentFilesList = [];

  @override
  void initState() {
    super.initState();
    _filterRecentFiles();
  }

  Future<void> _filterRecentFiles() async {
    List<FileModel> items = [];
    try {
      if (AuthManager.token != null && !AuthManager.token!.startsWith('google_token_')) {
        final response = await http.get(
          Uri.parse('https://mindspacenlp.com/api/drive/shared-with-me'),
          headers: {
            'Authorization': 'Bearer ${AuthManager.token}',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final List<dynamic> data = decoded['data'] ?? decoded['files'] ?? (decoded is List ? decoded : []);
          items = data.map((item) {
            final isFolder = item['is_folder'] == true || item['mime_type'] == 'folder';
            final name = (item['name'] ?? 'Untitled').toString();
            final mime = (item['mime_type'] ?? '').toString();
            final format = FileModel.detectFormat(name, mime, isFolder);

            String? url = (item['url'] ?? item['path'])?.toString();
            if (url != null && !url.startsWith('http')) url = 'https://mindspacenlp.com/$url';

            final customSize = item['size']?.toString();
            final rawBytes = item['size_bytes'] ?? item['bytes'] ?? item['file_size_bytes'] ?? item['size_in_bytes'];
            int parsedBytes = 0;
            if (rawBytes != null) {
              parsedBytes = int.tryParse(rawBytes.toString()) ?? 0;
            }
            if (parsedBytes <= 0) {
              parsedBytes = FileModel.parseSizeStringToBytes(customSize);
            }

            return FileModel(
              id: (item['id'] ?? DateTime.now().millisecondsSinceEpoch).toString(),
              name: name,
              format: format,
              sizeBytes: parsedBytes,
              customSizeString: customSize,
              uploadDate: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
              ownerName: item['owner'] ?? 'Shared',
              previewUrl: url,
            );
          }).toList();
        }
      }
    } catch (_) {}

    if (items.isEmpty) {
      items = await RecentService.getRecentFiles();
    }

    final List<FileModel> updatedItems = [];
    for (var file in items) {
      final isDl = await DownloadService.isFileDownloaded(file.name);
      if (isDl) {
        final localPath = await DownloadService.getLocalFilePath(file.name);
        updatedItems.add(FileModel(
          id: file.id,
          name: file.name,
          format: file.format,
          sizeBytes: file.sizeBytes,
          customSizeString: file.customSizeString,
          uploadDate: file.uploadDate,
          ownerName: file.ownerName,
          isPinned: file.isPinned,
          isFavorite: file.isFavorite,
          isDownloaded: true,
          previewUrl: localPath ?? file.previewUrl,
        ));
      } else {
        updatedItems.add(file);
      }
    }
    items = updatedItems;

    // Search filter
    if (_searchQuery.trim().isNotEmpty) {
      items = items.where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Category filter
    if (_activeFilter != 'All') {
      if (_activeFilter == 'PDFs') {
        items = items.where((f) => f.format.toLowerCase() == 'pdf').toList();
      } else if (_activeFilter == 'Images') {
        items = items.where((f) => ['png', 'jpg', 'jpeg', 'gif', 'webp', 'image'].contains(f.format.toLowerCase())).toList();
      } else if (_activeFilter == 'Videos') {
        items = items.where((f) => ['mp4', 'video', 'mov'].contains(f.format.toLowerCase())).toList();
      } else if (_activeFilter == 'Docs') {
        items = items.where((f) => ['doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'].contains(f.format.toLowerCase())).toList();
      }
    }

    // Sort favorites on top
    items.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return 0;
    });

    if (mounted) {
      setState(() {
        _recentFilesList = items;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Grouping
    final todayFiles = _recentFilesList.where((f) => _isToday(f.uploadDate)).toList();
    final yesterdayFiles = _recentFilesList.where((f) => _isYesterday(f.uploadDate)).toList();
    final lastWeekFiles = _recentFilesList
        .where((f) => !_isToday(f.uploadDate) && !_isYesterday(f.uploadDate))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Files',
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

              // Search Bar
              SearchBarWidget(
                hintText: 'Search recent files',
                onChanged: (val) {
                  _searchQuery = val;
                  _filterRecentFiles();
                },
                onFilterPressed: () => _showFilterSheet(context),
              ),
              const SizedBox(height: 16),

              // Horizontal Category Filter Pills
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterPill('All'),
                    _buildFilterPill('PDFs'),
                    _buildFilterPill('Images'),
                    _buildFilterPill('Videos'),
                    _buildFilterPill('Docs'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // File List / Grouped List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // TODO: API Integration Here - Refresh recent logs.
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: _recentFilesList.isEmpty
                      ? const EmptyWidget(
                          icon: Icons.history_rounded,
                          title: 'No Recent Files',
                          description: 'You haven\'t uploaded or viewed any files recently. Start uploading now!',
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (todayFiles.isNotEmpty) ...[
                                _buildGroupHeader('Today'),
                                _buildFileCollection(todayFiles),
                                const SizedBox(height: 16),
                              ],
                              if (yesterdayFiles.isNotEmpty) ...[
                                _buildGroupHeader('Yesterday'),
                                _buildFileCollection(yesterdayFiles),
                                const SizedBox(height: 16),
                              ],
                              if (lastWeekFiles.isNotEmpty) ...[
                                _buildGroupHeader('Older Files'),
                                _buildFileCollection(lastWeekFiles),
                                const SizedBox(height: 16),
                              ],
                            ],
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

  Widget _buildFilterPill(String title) {
    final theme = Theme.of(context);
    final isSelected = _activeFilter == title;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() {
              _activeFilter = title;
              _filterRecentFiles();
            });
          }
        },
        selectedColor: theme.colorScheme.primary,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
      ),
    );
  }

  Widget _buildFileCollection(List<FileModel> fileList) {
    if (_isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: fileList.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemBuilder: (context, index) {
          final file = fileList[index];
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
            onMenuSelected: (action) => _handleFileAction(file, action),
          );
        },
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: fileList.length,
        itemBuilder: (context, index) {
          final file = fileList[index];
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
            onMenuSelected: (action) => _handleFileAction(file, action),
          );
        },
      );
    }
  }

  void _showFilterSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 1,
            ),
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
              const SizedBox(height: 24),
              Text(
                'Sort Files',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.date_range_rounded),
                title: const Text('Date Modified (Newest First)', style: TextStyle(fontSize: 14)),
                trailing: Icon(Icons.check_rounded, color: theme.colorScheme.primary),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha_rounded),
                title: const Text('Name (A-Z)', style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _recentFilesList.sort((a, b) => a.name.compareTo(b.name));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.line_weight_rounded),
                title: const Text('Size (Largest First)', style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _recentFilesList.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  void _handleFileAction(FileModel file, String action) async {
    if (action == 'download') {
      final isCurrentlyDownloaded = file.isDownloaded;
      if (isCurrentlyDownloaded) {
        await DownloadService.deleteDownloadedFile(file.name);
        setState(() {
          _filterRecentFiles();
        });
        if (mounted) {
          AppToast.showInfo(context, '"${file.name}" removed from offline storage.');
        }
      } else {
        AppToast.showInfo(context, 'Saving "${file.name}" to local device storage...');
        final url = file.previewUrl ?? '';
        final ok = await DownloadService.downloadFile(url, file.name, model: file);
        if (ok) {
          setState(() {
            _filterRecentFiles();
          });
          if (mounted) {
            AppToast.showSuccess(context, '"${file.name}" saved locally for offline access!');
          }
        } else {
          if (mounted) {
            final error = DownloadService.downloadErrorNotifier.value ?? 'Failed to download "${file.name}". Please check internet connection.';
            AppToast.showError(context, error);
          }
        }
      }
    }
  }
}
