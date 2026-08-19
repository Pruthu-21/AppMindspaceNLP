import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../constants/mock_data.dart';
import '../../models/file_model.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/storage_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/file_card.dart';
import '../../services/role_manager.dart';
import '../../services/auth_manager.dart';
import '../../services/language_notifier.dart';
import '../../services/download_service.dart';
import '../../widgets/app_toast.dart';
import 'navigation_shell.dart';
import 'file_details_page.dart';
import 'folder_view_page.dart';
import 'preview/file_previewer_page.dart';
import '../../services/recent_service.dart';
import 'package:file_picker/file_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isGridView = true;
  String _searchQuery = '';
  List<FileModel> _filteredMyDriveFiles = [];
  List<FileModel> _filteredSharedWithMeFiles = [];
  List<FileModel> _recentFiles = [];
  List<FileModel> _myDriveFiles = [];
  List<FileModel> _sharedWithMeFiles = [];
  bool _isLoading = false;
  bool _isOffline = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedFileIds = {};

  void _toggleSelection(FileModel file) {
    setState(() {
      if (_selectedFileIds.contains(file.id)) {
        _selectedFileIds.remove(file.id);
        if (_selectedFileIds.isEmpty) {
          _isSelectionMode = false;
          NavigationShell.hideBottomNavNotifier.value = false;
        }
      } else {
        _selectedFileIds.add(file.id);
      }
    });
  }

  void _enterSelectionMode(FileModel file) {
    if (!RoleManager.isAdmin) return;
    setState(() {
      _isSelectionMode = true;
      _selectedFileIds.add(file.id);
      NavigationShell.hideBottomNavNotifier.value = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedFileIds.clear();
      NavigationShell.hideBottomNavNotifier.value = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _filteredMyDriveFiles = [];
    _filteredSharedWithMeFiles = [];
    _fetchSharedFiles();
  }

  List<FileModel> _parseFileList(String responseBody) {
    try {
      final dynamic decoded = jsonDecode(responseBody);
      List<dynamic> data = [];
      if (decoded is List) {
        data = decoded;
      } else if (decoded is Map) {
        if (decoded['data'] is List) data = decoded['data'] as List;
        else if (decoded['files'] is List) data = decoded['files'] as List;
        else if (decoded['items'] is List) data = decoded['items'] as List;
        else if (decoded['result'] is List) data = decoded['result'] as List;
      }

      return data.map((item) {
        final isFolder = item['is_folder'] == true || item['mime_type'] == 'folder' || item['type'] == 'folder';
        final String name = (item['name'] ?? item['title'] ?? 'Untitled').toString();
        final mime = (item['mime_type'] ?? item['type'] ?? '').toString();
        final format = FileModel.detectFormat(name, mime, isFolder);

        String? fileUrl = (item['url'] ?? item['file_url'] ?? item['download_url'] ?? item['path'] ?? item['link'])?.toString();
        if (fileUrl != null && fileUrl.isNotEmpty) {
          if (!fileUrl.startsWith('http://') && !fileUrl.startsWith('https://')) {
            if (!fileUrl.startsWith('/')) fileUrl = '/$fileUrl';
            if (!fileUrl.startsWith('/storage/') && fileUrl.startsWith('/drive/')) {
              fileUrl = '/storage$fileUrl';
            }
            fileUrl = 'https://mindspacenlp.com$fileUrl';
          }
        }

        final owner = (item['owner'] ?? item['owner_name'] ?? item['uploaded_by'] ?? 'Unknown').toString();

        final customSize = (item['size'] ?? item['file_size'])?.toString();
        final rawBytes = item['size_bytes'] ?? item['bytes'] ?? item['file_size_bytes'] ?? item['size_in_bytes'];
        int parsedBytes = 0;
        if (rawBytes != null) {
          parsedBytes = int.tryParse(rawBytes.toString()) ?? 0;
        }
        if (parsedBytes <= 0) {
          parsedBytes = FileModel.parseSizeStringToBytes(customSize);
        }

        return FileModel(
          id: (item['id'] ?? item['_id'] ?? DateTime.now().millisecondsSinceEpoch).toString(),
          name: name,
          format: format,
          sizeBytes: parsedBytes,
          customSizeString: customSize,
          uploadDate: DateTime.tryParse((item['created_at'] ?? item['uploaded_at'] ?? '').toString()) ?? DateTime.now(),
          ownerName: owner,
          previewUrl: fileUrl,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _fetchSharedFiles() async {
    if (AuthManager.token == null || AuthManager.token!.startsWith('google_token_')) {
      if (mounted) {
        AppToast.showError(context, 'Login incomplete — could not get session token. Please log out and sign in again.');
      }
      setState(() { _isLoading = false; });
      return;
    }

    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    try {
      final recents = await RecentService.getRecentFiles();

      // Fetch My Drive files
      List<FileModel> myDrive = [];
      try {
        final resMy = await http.get(
          Uri.parse('https://mindspacenlp.com/api/drive/my-drive'),
          headers: {'Authorization': 'Bearer ${AuthManager.token}', 'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (resMy.statusCode == 200) {
          myDrive = _parseFileList(resMy.body);
        }
      } catch (_) {}

      // Fetch Shared With Me files
      List<FileModel> shared = [];
      try {
        final resShared = await http.get(
          Uri.parse('https://mindspacenlp.com/api/drive/shared-with-me'),
          headers: {'Authorization': 'Bearer ${AuthManager.token}', 'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (resShared.statusCode == 200) {
          shared = _parseFileList(resShared.body);
        }
      } catch (_) {}

       final sharedIds = shared.map((s) => s.id).toSet();
      final cleanMyDrive = myDrive.where((f) => !sharedIds.contains(f.id)).toList();

      Future<List<FileModel>> updateOfflineStatus(List<FileModel> list) async {
        final List<FileModel> updated = [];
        for (var file in list) {
          final isDl = await DownloadService.isFileDownloaded(file.name);
          if (isDl) {
            final localPath = await DownloadService.getLocalFilePath(file.name);
            updated.add(FileModel(
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
            updated.add(file);
          }
        }
        return updated;
      }

      final updatedMyDrive = await updateOfflineStatus(cleanMyDrive);
      final updatedShared = await updateOfflineStatus(shared);
      final allLoaded = [...updatedMyDrive, ...updatedShared];

      setState(() {
        _recentFiles = recents;
        _myDriveFiles = updatedMyDrive;
        _sharedWithMeFiles = updatedShared;
        MockData.files.clear();
        MockData.files.addAll(allLoaded);
        _onSearchChanged(_searchQuery);
        _isLoading = false;
        _isOffline = false;
      });

    } catch (e) {
      final offlineFiles = await DownloadService.getOfflineFiles();
      setState(() {
        if (offlineFiles.isNotEmpty) {
          _sharedWithMeFiles = [];
          MockData.files.clear();
          MockData.files.addAll(offlineFiles);
          _onSearchChanged(_searchQuery);
        }
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  String _activeCategoryFilter = 'All';
  String _sortBy = 'Date';

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      final q = query.trim().toLowerCase();

      List<FileModel> myDrive = _myDriveFiles;
      List<FileModel> shared = _sharedWithMeFiles;

      // Apply category filter
      if (_activeCategoryFilter != 'All') {
        if (_activeCategoryFilter == 'Folders') {
          myDrive = myDrive.where((f) => f.isFolder).toList();
          shared = shared.where((f) => f.isFolder).toList();
        } else if (_activeCategoryFilter == 'PDFs') {
          myDrive = myDrive.where((f) => f.format.toLowerCase() == 'pdf').toList();
          shared = shared.where((f) => f.format.toLowerCase() == 'pdf').toList();
        } else if (_activeCategoryFilter == 'Images') {
          myDrive = myDrive.where((f) => ['png', 'jpg', 'jpeg', 'gif', 'webp', 'image'].contains(f.format.toLowerCase())).toList();
          shared = shared.where((f) => ['png', 'jpg', 'jpeg', 'gif', 'webp', 'image'].contains(f.format.toLowerCase())).toList();
        } else if (_activeCategoryFilter == 'Videos') {
          myDrive = myDrive.where((f) => ['mp4', 'video', 'mov'].contains(f.format.toLowerCase())).toList();
          shared = shared.where((f) => ['mp4', 'video', 'mov'].contains(f.format.toLowerCase())).toList();
        } else if (_activeCategoryFilter == 'Docs') {
          myDrive = myDrive.where((f) => ['doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'].contains(f.format.toLowerCase())).toList();
          shared = shared.where((f) => ['doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'].contains(f.format.toLowerCase())).toList();
        }
      }

      // Apply search query
      _filteredMyDriveFiles = q.isEmpty
          ? List<FileModel>.from(myDrive)
          : myDrive.where((f) => f.name.toLowerCase().contains(q)).toList();

      _filteredSharedWithMeFiles = q.isEmpty
          ? List<FileModel>.from(shared)
          : shared.where((f) => f.name.toLowerCase().contains(q)).toList();

      // Apply sorting
      if (_sortBy == 'Name') {
        _filteredMyDriveFiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _filteredSharedWithMeFiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else if (_sortBy == 'Size') {
        _filteredMyDriveFiles.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        _filteredSharedWithMeFiles.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      } else {
        // Default sort: Favorites to top
        _filteredMyDriveFiles.sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          return 0;
        });

        _filteredSharedWithMeFiles.sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          return 0;
        });
      }
    });
  }

  void _showFilterSheet(BuildContext context) {
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
                    'Filter & Sort Files',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('Filter by Type', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'Folders', 'PDFs', 'Images', 'Videos', 'Docs'].map((cat) {
                      final isSelected = _activeCategoryFilter == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _activeCategoryFilter = cat;
                              _onSearchChanged(_searchQuery);
                            });
                            setSheetState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Sort by', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Date', 'Name', 'Size'].map((sort) {
                      final isSelected = _sortBy == sort;
                      return ChoiceChip(
                        label: Text(sort),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _sortBy = sort;
                              _onSearchChanged(_searchQuery);
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

  Future<void> _handleRealFileUpload() async {
    if (AuthManager.token == null || AuthManager.token!.startsWith('google_token_')) {
      AppToast.showError(context, 'Please sign in to upload files.');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        if (mounted) AppToast.showInfo(context, 'Uploading ${result.files.length} file(s)...');

        final uri = Uri.parse('https://mindspacenlp.com/api/admin/drive/upload');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer ${AuthManager.token}';
        request.headers['Accept'] = 'application/json';

        for (var picked in result.files) {
          if (picked.path != null) {
            request.files.add(await http.MultipartFile.fromPath('files[]', picked.path!));
          } else if (picked.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes('files[]', picked.bytes!, filename: picked.name));
          }
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (mounted) AppToast.showSuccess(context, 'File(s) uploaded successfully!');
          await _fetchSharedFiles();
        } else {
          if (mounted) AppToast.showError(context, 'Upload failed (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error picking/uploading file: $e');
    }
  }

  void _showUploadBottomSheet(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                'Create New',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSheetItem(
                    context,
                    Icons.create_new_folder_rounded,
                    'Folder',
                    Colors.amber.shade600,
                    () {
                      Navigator.pop(context);
                      _showCreateFolderDialog();
                    },
                  ),
                  _buildSheetItem(
                    context,
                    Icons.upload_file_rounded,
                    'Upload File',
                    AppColors.primary,
                    () {
                      Navigator.pop(context);
                      _handleRealFileUpload();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final folderController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'New Folder',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: folderController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Folder Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final folderName = folderController.text.trim();
                if (folderName.isNotEmpty) {
                  Navigator.pop(dialogCtx);
                  try {
                    final response = await http.post(
                      Uri.parse('https://mindspacenlp.com/api/drive/folder/create'),
                      headers: {
                        'Authorization': 'Bearer ${AuthManager.token}',
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                      },
                      body: jsonEncode({
                        'name': folderName,
                      }),
                    );

                    if (response.statusCode == 200 || response.statusCode == 201) {
                      if (mounted) AppToast.showSuccess(context, 'Folder "$folderName" created!');
                      await _fetchSharedFiles();
                    } else {
                      if (mounted) AppToast.showError(context, 'Failed to create folder (${response.statusCode})');
                    }
                  } catch (e) {
                    if (mounted) AppToast.showError(context, 'Error creating folder: $e');
                  }
                }
              },
              child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSheetItem(
      BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrOfflineState(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_isOffline) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Connection',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your network settings and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchSharedFiles,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }
    
    // Data not found / Empty state
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              color: theme.colorScheme.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Files Found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No files or folders are currently shared with you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final folders = _filteredMyDriveFiles.where((f) => f.isFolder).toList();
    final filesOnly = _filteredMyDriveFiles.where((f) => !f.isFolder).toList();

    return ValueListenableBuilder<AppRole>(
      valueListenable: RoleManager.roleNotifier,
      builder: (context, currentRole, child) {
        final isAdmin = currentRole == AppRole.admin;

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetchSharedFiles();
              },
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 160), // Extra bottom padding so FAB never overlaps file cards
                children: [
                  // Greeting Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${LanguageNotifier.translate('hello')}, ${AuthManager.currentUser?.name.split(' ').first ?? 'Guest'}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAdmin 
                                ? LanguageNotifier.translate('admin_dashboard') 
                                : LanguageNotifier.translate('manage_space'),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: DownloadService.isDownloadingNotifier,
                            builder: (context, isDl, child) {
                              if (!isDl) return const SizedBox.shrink();
                              return ValueListenableBuilder<String?>(
                                valueListenable: DownloadService.currentDownloadingFileNameNotifier,
                                builder: (context, fileName, child) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ValueListenableBuilder<double>(
                                          valueListenable: DownloadService.getProgressNotifierFor(fileName ?? ''),
                                          builder: (context, progress, child) {
                                            final pct = (progress * 100).toStringAsFixed(1);
                                            final label = progress > 0 ? 'Saving $pct%' : 'Saving...';
                                            return Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          GestureDetector(
                            onTap: () {
                              NavigationShell.navigationNotifier.value = 4; // Navigate to Profile Tab
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                ),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  AuthManager.currentUser?.initials ?? 'MS',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Search Bar
                  SearchBarWidget(
                    hintText: 'Search files and folders',
                    onChanged: _onSearchChanged,
                    onFilterPressed: () => _showFilterSheet(context),
                  ),
                  const SizedBox(height: 24),

                  // Recents Section (On top of Home Page)
                  if (_recentFiles.isNotEmpty) ...[
                    const SectionHeader(title: 'Recent Files'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _recentFiles.length,
                        itemBuilder: (context, index) {
                          final file = _recentFiles[index];
                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            child: FileCard(
                              file: file,
                              isGrid: true,
                              isSelectionMode: _isSelectionMode,
                              isSelected: _selectedFileIds.contains(file.id),
                              onLongPress: () => _enterSelectionMode(file),
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(file);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FileDetailsPage(file: file),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Quick Actions (Admin Only)
                  if (isAdmin) ...[
                    const SectionHeader(title: 'Quick Actions'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showUploadBottomSheet(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded, color: theme.colorScheme.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add File',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _showCreateFolderDialog,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_open_rounded,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'New Folder',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // My Uploaded Files Section (Admin Only)
                  if (isAdmin && (filesOnly.isNotEmpty || folders.isNotEmpty)) ...[
                    SectionHeader(
                      title: 'My Uploaded Files',
                      trailing: IconButton(
                        icon: Icon(
                          _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _isGridView = !_isGridView;
                          });
                        },
                      ),
                    ),
                    if (folders.isNotEmpty) ...[
                      _isGridView
                          ? GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: folders.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.5,
                              ),
                              itemBuilder: (context, index) {
                                final folder = folders[index];
                                return FileCard(
                                  file: folder,
                                  isGrid: true,
                                  isSelectionMode: _isSelectionMode,
                                  isSelected: _selectedFileIds.contains(folder.id),
                                  onLongPress: () => _enterSelectionMode(folder),
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleSelection(folder);
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FolderViewPage(folder: folder),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: folders.length,
                              itemBuilder: (context, index) {
                                final folder = folders[index];
                                return FileCard(
                                  file: folder,
                                  isGrid: false,
                                  isSelectionMode: _isSelectionMode,
                                  isSelected: _selectedFileIds.contains(folder.id),
                                  onLongPress: () => _enterSelectionMode(folder),
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleSelection(folder);
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FolderViewPage(folder: folder),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                      const SizedBox(height: 16),
                    ],
                    if (filesOnly.isNotEmpty) ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filesOnly.length,
                        itemBuilder: (context, index) {
                          final file = filesOnly[index];
                          return FileCard(
                            file: file,
                            isGrid: false,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedFileIds.contains(file.id),
                            onLongPress: () => _enterSelectionMode(file),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(file);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FileDetailsPage(file: file),
                                  ),
                                );
                              }
                            },
                            onMenuSelected: (action) {
                              _handleFileAction(file, action);
                            },
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  // Shared With Me Section (For all users / admins)
                  if (_filteredSharedWithMeFiles.isNotEmpty) ...[
                    const SectionHeader(title: 'Shared With Me'),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredSharedWithMeFiles.length,
                      itemBuilder: (context, index) {
                        final file = _filteredSharedWithMeFiles[index];
                        return FileCard(
                          file: file,
                          isGrid: false,
                          isSelectionMode: _isSelectionMode,
                          isSelected: _selectedFileIds.contains(file.id),
                          onLongPress: () => _enterSelectionMode(file),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(file);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FileDetailsPage(file: file),
                                ),
                              );
                            }
                          },
                          onMenuSelected: (action) {
                            _handleFileAction(file, action);
                          },
                        );
                      },
                    ),
                  ],

                  // Empty Search Result / Offline / Empty Drive
                  if (_filteredMyDriveFiles.isEmpty && _filteredSharedWithMeFiles.isEmpty) ...[
                    if (_searchQuery.trim().isEmpty)
                      _buildEmptyOrOfflineState(theme, isDark)
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60.0),
                        child: Center(
                          child: Text('No files match your search query.', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar: _isSelectionMode
              ? _buildMultiSelectBottomBar(context, theme, isDark)
              : null,
          floatingActionButton: (isAdmin && !_isSelectionMode)
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 78.0),
                  child: FloatingActionButton(
                    onPressed: () => _showUploadBottomSheet(context),
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildMultiSelectBottomBar(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey),
              onPressed: _clearSelection,
              tooltip: 'Cancel',
            ),
            Text(
              '${_selectedFileIds.length} Selected',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.blue),
              tooltip: 'Share',
              onPressed: _batchShare,
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move_rounded, color: Colors.amber),
              tooltip: 'Move',
              onPressed: _batchMove,
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              tooltip: 'Delete',
              onPressed: _batchDelete,
            ),
          ],
        ),
      ),
    );
  }

  void _batchShare() {
    if (_selectedFileIds.isEmpty) return;
    _showShareDialog(_selectedFileIds.toList());
  }

  void _batchMove() {
    if (_selectedFileIds.isEmpty) return;
    _showMoveDialog(_selectedFileIds.toList());
  }

  void _batchDelete() async {
    if (_selectedFileIds.isEmpty) return;
    final ids = _selectedFileIds.toList();

    // Separate folder and file IDs
    final List<String> fileIds = [];
    final List<String> folderIds = [];
    for (var id in ids) {
      final match = [..._myDriveFiles, ..._sharedWithMeFiles].firstWhere(
        (f) => f.id == id,
        orElse: () => FileModel(id: id, name: '', format: '', sizeBytes: 0, uploadDate: DateTime.now(), ownerName: ''),
      );
      if (match.isFolder) {
        folderIds.add(id);
      } else {
        fileIds.add(id);
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Items', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete these ${ids.length} item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _clearSelection();

              try {
                final response = await http.post(
                  Uri.parse('https://mindspacenlp.com/api/admin/drive/delete'),
                  headers: {
                    'Authorization': 'Bearer ${AuthManager.token}',
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                  body: jsonEncode({
                    'file_ids': fileIds,
                    'folder_ids': folderIds,
                  }),
                );

                if (response.statusCode == 200) {
                  if (mounted) AppToast.showSuccess(context, 'Items deleted successfully.');
                  await _fetchSharedFiles();
                } else {
                  if (mounted) AppToast.showError(context, 'Delete failed (${response.statusCode})');
                }
              } catch (e) {
                if (mounted) AppToast.showError(context, 'Delete error: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(FileModel file) {
    final controller = TextEditingController(text: file.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != file.name) {
                Navigator.pop(context);
                try {
                  final response = await http.post(
                    Uri.parse('https://mindspacenlp.com/api/admin/drive/rename'),
                    headers: {
                      'Authorization': 'Bearer ${AuthManager.token}',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'item_id': int.tryParse(file.id) ?? file.id,
                      'item_type': file.isFolder ? 'folder' : 'file',
                      'new_name': newName,
                    }),
                  );
                  if (response.statusCode == 200) {
                    AppToast.showSuccess(context, 'Renamed to "$newName"');
                    await _fetchSharedFiles();
                  }
                } catch (e) {
                  AppToast.showError(context, 'Rename failed: $e');
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(List<String> fileIds) async {
    List<dynamic> usersList = [];
    bool isFetchingUsers = true;
    Set<int> selectedUserIds = {};
    String searchUserQuery = '';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isFetchingUsers) {
              Future.wait([
                http.get(
                  Uri.parse('https://mindspacenlp.com/api/drive/users'),
                  headers: {
                    'Authorization': 'Bearer ${AuthManager.token}',
                    'Accept': 'application/json',
                  },
                ),
                if (fileIds.isNotEmpty)
                  http.get(
                    Uri.parse('https://mindspacenlp.com/api/drive/file/${fileIds.first}/shared-users'),
                    headers: {
                      'Authorization': 'Bearer ${AuthManager.token}',
                      'Accept': 'application/json',
                    },
                  ),
              ]).then((responses) {
                final usersRes = responses[0];
                if (usersRes.statusCode == 200) {
                  final decoded = jsonDecode(usersRes.body);
                  final data = decoded['data'] ?? (decoded is List ? decoded : []);
                  usersList = data is List ? data : [];
                }

                if (responses.length > 1 && responses[1].statusCode == 200) {
                  final decodedShared = jsonDecode(responses[1].body);
                  final List<dynamic> sharedData = decodedShared is List
                      ? decodedShared
                      : (decodedShared['data'] is List ? decodedShared['data'] : []);

                  for (var su in sharedData) {
                    final int sId = int.tryParse(su['id']?.toString() ?? '') ?? 0;
                    if (sId > 0) selectedUserIds.add(sId);
                  }
                }

                setDialogState(() {
                  isFetchingUsers = false;
                });
              }).catchError((_) {
                setDialogState(() {
                  isFetchingUsers = false;
                });
              });
            }

            final filteredUsers = usersList.where((u) {
              final name = (u['name'] ?? '').toString().toLowerCase();
              final email = (u['email'] ?? '').toString().toLowerCase();
              final q = searchUserQuery.trim().toLowerCase();
              return q.isEmpty || name.contains(q) || email.contains(q);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Share ${fileIds.length} Item(s)'),
              content: SizedBox(
                width: double.maxFinite,
                height: 360,
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) {
                        setDialogState(() {
                          searchUserQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search user by name or email...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: isFetchingUsers
                          ? const Center(child: CircularProgressIndicator())
                          : (filteredUsers.isEmpty
                              ? const Center(child: Text('No matching users found.'))
                              : ListView.builder(
                                  itemCount: filteredUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = filteredUsers[index];
                                    final int uId = int.tryParse(user['id']?.toString() ?? '') ?? 0;
                                    final uName = user['name'] ?? 'User';
                                    final uEmail = user['email'] ?? '';
                                    final isSelected = selectedUserIds.contains(uId);

                                    return CheckboxListTile(
                                      value: isSelected,
                                      title: Text(uName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      subtitle: Text(uEmail, style: const TextStyle(fontSize: 12)),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            selectedUserIds.add(uId);
                                          } else {
                                            selectedUserIds.remove(uId);
                                          }
                                        });
                                      },
                                    );
                                  },
                                )),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    try {
                      final response = await http.post(
                        Uri.parse('https://mindspacenlp.com/api/drive/share'),
                        headers: {
                          'Authorization': 'Bearer ${AuthManager.token}',
                          'Content-Type': 'application/json',
                          'Accept': 'application/json',
                        },
                        body: jsonEncode({
                          'file_ids': fileIds,
                          'user_ids': selectedUserIds.toList(),
                        }),
                      );

                      if (response.statusCode == 200) {
                        AppToast.showSuccess(context, 'Sharing permissions updated successfully!');
                        await _fetchSharedFiles();
                      } else {
                        AppToast.showError(context, 'Update failed (${response.statusCode})');
                      }
                    } catch (e) {
                      AppToast.showError(context, 'Sharing error: $e');
                    }
                    _clearSelection();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMoveDialog(List<String> selectedIds) {
    if (selectedIds.isEmpty) return;

    List<String> fileIdsToMove = [];
    List<String> folderIdsToMove = [];

    for (var id in selectedIds) {
      final match = [..._myDriveFiles, ..._sharedWithMeFiles].firstWhere(
        (f) => f.id == id,
        orElse: () => FileModel(id: id, name: '', format: '', sizeBytes: 0, uploadDate: DateTime.now(), ownerName: ''),
      );
      if (match.isFolder) {
        folderIdsToMove.add(id);
      } else {
        fileIdsToMove.add(id);
      }
    }

    final availableFolders = _myDriveFiles.where((f) => f.isFolder && !folderIdsToMove.contains(f.id)).toList();
    String? selectedTargetFolderId;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Move ${selectedIds.length} Item(s) to...'),
              content: SizedBox(
                width: double.maxFinite,
                height: 320,
                child: ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_special_rounded, color: Colors.blue, size: 28),
                      title: const Text('Root Directory ( / )', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text('Main My Drive location', style: TextStyle(fontSize: 12)),
                      trailing: selectedTargetFolderId == null
                          ? const Icon(Icons.check_circle_rounded, color: Colors.blue)
                          : const Icon(Icons.circle_outlined, color: Colors.grey),
                      onTap: () {
                        setDialogState(() {
                          selectedTargetFolderId = null;
                        });
                      },
                    ),
                    const Divider(),
                    if (availableFolders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No sub-folders available.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...availableFolders.map((folder) {
                        final isSelected = selectedTargetFolderId == folder.id;
                        return ListTile(
                          leading: Icon(Icons.folder_rounded, color: Colors.amber.shade600, size: 28),
                          title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Folder', style: TextStyle(fontSize: 12)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: Colors.blue)
                              : const Icon(Icons.circle_outlined, color: Colors.grey),
                          onTap: () {
                            setDialogState(() {
                              selectedTargetFolderId = folder.id;
                            });
                          },
                        );
                      }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    _clearSelection();
                    try {
                      final response = await http.post(
                        Uri.parse('https://mindspacenlp.com/api/drive/move'),
                        headers: {
                          'Authorization': 'Bearer ${AuthManager.token}',
                          'Content-Type': 'application/json',
                          'Accept': 'application/json',
                        },
                        body: jsonEncode({
                          'file_ids': fileIdsToMove,
                          'folder_ids': folderIdsToMove,
                          'target_folder_id': selectedTargetFolderId != null ? int.tryParse(selectedTargetFolderId!) : null,
                        }),
                      );

                      if (response.statusCode == 200) {
                        if (mounted) AppToast.showSuccess(context, 'Moved successfully!');
                        await _fetchSharedFiles();
                      } else {
                        if (mounted) AppToast.showError(context, 'Move failed (${response.statusCode})');
                      }
                    } catch (e) {
                      if (mounted) AppToast.showError(context, 'Move error: $e');
                    }
                  },
                  child: const Text('Move Here'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleFileAction(FileModel file, String action) async {
    if (action == 'delete') {
      _selectedFileIds.clear();
      _selectedFileIds.add(file.id);
      _batchDelete();
    } else if (action == 'rename') {
      _showRenameDialog(file);
    } else if (action == 'share') {
      _showShareDialog([file.id]);
    } else if (action == 'move') {
      _showMoveDialog([file.id]);
    } else if (action == 'favorite') {
      setState(() {
        final index = MockData.files.indexWhere((f) => f.id == file.id);
        if (index != -1) {
          final isFav = MockData.files[index].isFavorite;
          MockData.files[index] = FileModel(
            id: file.id,
            name: file.name,
            format: file.format,
            sizeBytes: file.sizeBytes,
            uploadDate: file.uploadDate,
            ownerName: file.ownerName,
            isPinned: file.isPinned,
            isFavorite: !isFav,
            isDownloaded: file.isDownloaded,
            previewUrl: file.previewUrl,
          );
          _onSearchChanged(_searchQuery);
        }
      });
    } else if (action == 'download') {
      final isCurrentlyDownloaded = file.isDownloaded;
      if (isCurrentlyDownloaded) {
        await DownloadService.deleteDownloadedFile(file.name);
        setState(() {
          final index = MockData.files.indexWhere((f) => f.id == file.id);
          if (index != -1) {
            MockData.files[index] = FileModel(
              id: file.id,
              name: file.name,
              format: file.format,
              sizeBytes: file.sizeBytes,
              uploadDate: file.uploadDate,
              ownerName: file.ownerName,
              isPinned: file.isPinned,
              isFavorite: file.isFavorite,
              isDownloaded: false,
              previewUrl: file.previewUrl,
            );
            _onSearchChanged(_searchQuery);
          }
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
            final index = MockData.files.indexWhere((f) => f.id == file.id);
            if (index != -1) {
              MockData.files[index] = FileModel(
                id: file.id,
                name: file.name,
                format: file.format,
                sizeBytes: file.sizeBytes,
                uploadDate: file.uploadDate,
                ownerName: file.ownerName,
                isPinned: file.isPinned,
                isFavorite: file.isFavorite,
                isDownloaded: true,
                previewUrl: file.previewUrl,
              );
              _onSearchChanged(_searchQuery);
            }
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
