import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../constants/app_colors.dart';
import '../models/file_model.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/file_card.dart';
import 'dialogs/rename_dialog.dart';
import 'dialogs/share_dialog.dart';
import 'dialogs/move_dialog.dart';
import '../widgets/states/loading_skeleton.dart';
import '../widgets/states/empty_state.dart';
import 'navigation_shell.dart';

import '../services/auth_manager.dart';
import '../services/role_manager.dart';
import '../widgets/app_toast.dart';
import '../utils/error_helper.dart';
import 'file_details_page.dart';
import '../services/download_service.dart';

Map<String, List<Map<String, dynamic>>> parseFolderContentsResponse(
  String responseBody,
) {
  try {
    final decoded = jsonDecode(responseBody);
    List<dynamic> rawFiles = [];
    List<dynamic> rawFolders = [];

    if (decoded is Map) {
      if (decoded['files'] is List) rawFiles = decoded['files'];
      if (decoded['folders'] is List) rawFolders = decoded['folders'];
      if (rawFiles.isEmpty && rawFolders.isEmpty && decoded['data'] is List) {
        final List<dynamic> data = decoded['data'];
        for (var item in data) {
          if (item['is_folder'] == true) {
            rawFolders.add(item);
          } else {
            rawFiles.add(item);
          }
        }
      }
    } else if (decoded is List) {
      for (var item in decoded) {
        if (item['is_folder'] == true) {
          rawFolders.add(item);
        } else {
          rawFiles.add(item);
        }
      }
    }
    return {
      'rawFiles': rawFiles.map((e) => e as Map<String, dynamic>).toList(),
      'rawFolders': rawFolders.map((e) => e as Map<String, dynamic>).toList(),
    };
  } catch (e) {
    debugPrint('Error parsing folder contents: $e');
    return {'rawFiles': [], 'rawFolders': []};
  }
}

class FolderViewPage extends StatefulWidget {
  final FileModel folder;

  const FolderViewPage({super.key, required this.folder});

  @override
  State<FolderViewPage> createState() => _FolderViewPageState();
}

class _FolderViewPageState extends State<FolderViewPage> {
  bool _isGridView = false;
  String _searchQuery = '';
  List<FileModel> _allSubItems = [];
  List<FileModel> _filteredItems = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<String> _selectedFileIds = {};

  @override
  void initState() {
    super.initState();
    _fetchFolderContents();
  }

  void _toggleSelection(FileModel file) {
    setState(() {
      if (_selectedFileIds.contains(file.id)) {
        _selectedFileIds.remove(file.id);
        if (_selectedFileIds.isEmpty) {
          _isSelectionMode = false;
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
    });
  }

  Future<void> _fetchFolderContents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://mindspacenlp.com/api/drive/folder/${widget.folder.id}/contents',
            ),
            headers: {
              'Authorization': 'Bearer ${AuthManager.token}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final parsedData = await compute(
          parseFolderContentsResponse,
          response.body,
        );
        List<Map<String, dynamic>> rawFiles = parsedData['rawFiles'] ?? [];
        List<Map<String, dynamic>> rawFolders = parsedData['rawFolders'] ?? [];

        final parsedFolders = rawFolders.map((item) {
          return FileModel(
            id: (item['id'] ?? DateTime.now().millisecondsSinceEpoch)
                .toString(),
            name: (item['name'] ?? 'Untitled Folder').toString(),
            format: 'folder',
            sizeBytes: 0,
            uploadDate:
                DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            ownerName: item['owner'] ?? 'Admin',
          );
        }).toList();

        final parsedFiles = rawFiles.map((item) {
          final String name = (item['name'] ?? 'Untitled File').toString();
          final mime = (item['mime_type'] ?? '').toString();
          final format = FileModel.detectFormat(name, mime, false);

          String? url = (item['url'] ?? item['path'])?.toString();
          if (url != null && url.isNotEmpty) {
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              if (!url.startsWith('/')) url = '/$url';
              if (!url.startsWith('/storage/') && url.startsWith('/drive/')) {
                url = '/storage$url';
              }
              url = 'https://mindspacenlp.com$url';
            }
          }

          final customSize = item['size']?.toString();
          final rawBytes =
              item['size_bytes'] ??
              item['bytes'] ??
              item['file_size_bytes'] ??
              item['size_in_bytes'];
          int parsedBytes = 0;
          if (rawBytes != null) {
            parsedBytes = int.tryParse(rawBytes.toString()) ?? 0;
          }
          if (parsedBytes <= 0) {
            parsedBytes = FileModel.parseSizeStringToBytes(customSize);
          }

          return FileModel(
            id: (item['id'] ?? DateTime.now().millisecondsSinceEpoch)
                .toString(),
            name: name,
            format: format,
            sizeBytes: parsedBytes,
            customSizeString: customSize,
            uploadDate:
                DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            ownerName: item['owner'] ?? 'Admin',
            previewUrl: url,
          );
        }).toList();

        final List<FileModel> updatedFiles = [];
        for (var file in parsedFiles) {
          final isDl = await DownloadService.isFileDownloaded(file.name);
          if (isDl) {
            final localPath = await DownloadService.getLocalFilePath(file.name);
            updatedFiles.add(
              FileModel(
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
              ),
            );
          } else {
            updatedFiles.add(file);
          }
        }

        final items = [...parsedFolders, ...updatedFiles];
        setState(() {
          _allSubItems = items;
          _filterItems();
          _isLoading = false;
        });
      } else {
        setState(() {
          _allSubItems = [];
          _filteredItems = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterItems() {
    final q = _searchQuery.trim().toLowerCase();
    setState(() {
      _filteredItems = q.isEmpty
          ? List<FileModel>.from(_allSubItems)
          : _allSubItems
                .where((f) => f.name.toLowerCase().contains(q))
                .toList();
    });
  }

  Future<void> _handleUploadToFolder() async {
    if (AuthManager.token == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        if (mounted)
          AppToast.showInfo(
            context,
            'Uploading file(s) into "${widget.folder.name}"...',
          );

        final uri = Uri.parse(
          'https://mindspacenlp.com/api/admin/drive/upload',
        );
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer ${AuthManager.token}';
        request.headers['Accept'] = 'application/json';
        request.fields['folder_id'] = widget.folder.id;

        for (var picked in result.files) {
          if (picked.path != null) {
            request.files.add(
              await http.MultipartFile.fromPath('files[]', picked.path!),
            );
          } else if (picked.bytes != null) {
            request.files.add(
              http.MultipartFile.fromBytes(
                'files[]',
                picked.bytes!,
                filename: picked.name,
              ),
            );
          }
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (mounted) AppToast.showSuccess(context, 'Uploaded successfully!');
          await _fetchFolderContents();
        } else {
          if (mounted)
            AppToast.showError(
              context,
              ErrorHelper.getFriendlyMessage(null, response.statusCode),
            );
        }
      }
    } catch (e) {
      if (mounted)
        AppToast.showError(context, ErrorHelper.getFriendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = RoleManager.isAdmin;
    final isDark = theme.brightness == Brightness.dark;

    final subFolders = _filteredItems.where((f) => f.isFolder).toList();
    final subFiles = _filteredItems.where((f) => !f.isFolder).toList();

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (_isSelectionMode) {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Icon(
                Icons.folder_rounded,
                color: Colors.amber.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.folder.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              ),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
            ),
          ],
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                SearchBarWidget(
                  hintText: 'Search inside ${widget.folder.name}',
                  onChanged: (val) {
                    _searchQuery = val;
                    _filterItems();
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchFolderContents,
                    child: _isLoading
                        ? (_isGridView
                              ? const FileGridSkeleton()
                              : const FileListSkeleton())
                        : (_filteredItems.isEmpty
                              ? const EmptyWidget(
                                  icon: Icons.folder_open_rounded,
                                  title: 'Folder is Empty',
                                  description:
                                      'No files or subfolders found inside this folder.',
                                )
                              : ListView(
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    if (subFolders.isNotEmpty) ...[
                                      Text(
                                        'Folders (${subFolders.length})',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildItemGridOrList(subFolders),
                                      const SizedBox(height: 16),
                                    ],
                                    if (subFiles.isNotEmpty) ...[
                                      Text(
                                        'Files (${subFiles.length})',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildItemGridOrList(subFiles),
                                    ],
                                  ],
                                )),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: (isAdmin && !_isSelectionMode)
            ? FloatingActionButton.extended(
                onPressed: _handleUploadToFolder,
                backgroundColor: theme.colorScheme.primary,
                icon: const Icon(
                  Icons.upload_file_rounded,
                  color: Colors.white,
                ),
                label: const Text(
                  'Add File',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        bottomNavigationBar: _isSelectionMode
            ? _buildMultiSelectBottomBar(context, theme, isDark)
            : null,
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedFileIds.clear();
      _isSelectionMode = false;
      NavigationShell.hideBottomNavNotifier.value = false;
    });
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
      final match = _allSubItems.firstWhere(
        (f) => f.id == id,
        orElse: () => FileModel(
          id: id,
          name: '',
          format: '',
          sizeBytes: 0,
          uploadDate: DateTime.now(),
          ownerName: '',
        ),
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
        title: const Text(
          'Delete Items',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete these ${ids.length} item(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
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
                  if (mounted)
                    AppToast.showSuccess(
                      context,
                      'Items deleted successfully.',
                    );
                  await _fetchFolderContents();
                } else {
                  if (mounted)
                    AppToast.showError(
                      context,
                      ErrorHelper.getFriendlyMessage(null, response.statusCode),
                    );
                }
              } catch (e) {
                if (mounted)
                  AppToast.showError(
                    context,
                    ErrorHelper.getFriendlyMessage(e),
                  );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(FileModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${item.isFolder ? "Folder" : "File"}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final response = await http.post(
                  Uri.parse('https://mindspacenlp.com/api/admin/drive/delete'),
                  headers: {
                    'Authorization': 'Bearer ${AuthManager.token}',
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                  body: jsonEncode({
                    'file_ids': item.isFolder ? [] : [item.id],
                    'folder_ids': item.isFolder ? [item.id] : [],
                  }),
                );

                if (response.statusCode == 200) {
                  if (mounted)
                    AppToast.showSuccess(
                      context,
                      '"${item.name}" deleted successfully.',
                    );
                  await _fetchFolderContents();
                } else {
                  if (mounted)
                    AppToast.showError(
                      context,
                      ErrorHelper.getFriendlyMessage(null, response.statusCode),
                    );
                }
              } catch (e) {
                if (mounted)
                  AppToast.showError(
                    context,
                    ErrorHelper.getFriendlyMessage(e),
                  );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(List<String> fileIds) async {
    final selectedUserIds = await ShareDialog.show(context, fileIds);
    if (selectedUserIds != null) {
      _clearSelection();
      try {
        final response = await http.post(
          Uri.parse('https://mindspacenlp.com/api/drive/share'),
          headers: {
            'Authorization': 'Bearer ${AuthManager.token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'file_ids': fileIds, 'user_ids': selectedUserIds}),
        );
        if (!mounted) return;
        if (response.statusCode == 200) {
          AppToast.showSuccess(context, 'Shared successfully!');
          _fetchFolderContents();
        } else {
          AppToast.showError(
            context,
            ErrorHelper.getFriendlyMessage(null, response.statusCode),
          );
        }
      } catch (e) {
        if (!mounted) return;
        AppToast.showError(context, ErrorHelper.getFriendlyMessage(e));
      }
    }
  }

  void _showMoveDialog(List<String> selectedIds) async {
    if (selectedIds.isEmpty) return;

    List<String> fileIdsToMove = [];
    List<String> folderIdsToMove = [];

    for (var id in selectedIds) {
      final match = _allSubItems.firstWhere(
        (f) => f.id == id,
        orElse: () => FileModel(
          id: id,
          name: '',
          format: '',
          sizeBytes: 0,
          uploadDate: DateTime.now(),
          ownerName: '',
        ),
      );
      if (match.isFolder) {
        folderIdsToMove.add(id);
      } else {
        fileIdsToMove.add(id);
      }
    }

    final availableFolders = _allSubItems
        .where((f) => f.isFolder && !folderIdsToMove.contains(f.id))
        .toList();

    final targetFolderId = await MoveDialog.show(
      context,
      selectedIds.length,
      availableFolders,
    );

    if (targetFolderId != null) {
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
            'target_folder_id': targetFolderId == -1 ? null : targetFolderId,
          }),
        );

        if (!mounted) return;
        if (response.statusCode == 200) {
          AppToast.showSuccess(context, 'Moved successfully!');
          _fetchFolderContents();
        } else {
          AppToast.showError(
            context,
            ErrorHelper.getFriendlyMessage(null, response.statusCode),
          );
        }
      } catch (e) {
        if (!mounted) return;
        AppToast.showError(context, ErrorHelper.getFriendlyMessage(e));
      }
    }
  }

  void _handleDeleteOfflineAction(FileModel file) async {
    if (file.isFolder) return;
    debugPrint(
      'MSNLP_DOWNLOAD | ACTION action=DELETE fileId=${file.id} fileName=${file.name}',
    );
    debugPrint('MSNLP_FILE | DELETE_START fileId=${file.id}');
    try {
      await DownloadService.deleteDownloadedFile(file.name);
      debugPrint('MSNLP_FILE | PHYSICAL_DELETE path=${file.name} success=true');
      debugPrint('MSNLP_FILE | METADATA_DELETE fileId=${file.id} success=true');
      if (mounted) {
        AppToast.showInfo(
          context,
          '"${file.name}" removed from offline storage.',
        );
        await _fetchFolderContents();
      }
    } catch (e, stack) {
      debugPrint(
        'MSNLP_FILE | PHYSICAL_DELETE path=${file.name} success=false error=$e stack=$stack',
      );
    }
  }

  void _handleDownloadAction(FileModel file) async {
    debugPrint(
      'MSNLP_DOWNLOAD | REQUEST fileId=${file.id} fileName=${file.name} source=three_dot url_available=${file.previewUrl != null}',
    );
    if (file.isFolder) return;
    AppToast.showInfo(
      context,
      'Saving "${file.name}" to local device storage...',
    );
    final url = file.previewUrl ?? '';
    final ok = await DownloadService.downloadFile(url, file.name, model: file);
    if (ok) {
      if (mounted) {
        AppToast.showSuccess(
          context,
          '"${file.name}" saved locally for offline access!',
        );
        await _fetchFolderContents();
      }
    } else {
      if (mounted) {
        final error =
            DownloadService.downloadErrorNotifier.value ??
            'Failed to download "${file.name}". Please check internet connection.';
        AppToast.showError(context, ErrorHelper.getFriendlyMessage(error));
      }
    }
  }

  Widget _buildMultiSelectBottomBar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
              icon: const Icon(
                Icons.drive_file_move_rounded,
                color: Colors.amber,
              ),
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

  void _showRenameDialog(FileModel item) async {
    final newName = await RenameDialog.show(context, item);
    if (newName != null && newName.isNotEmpty && newName != item.name) {
      try {
        final response = await http.post(
          Uri.parse('https://mindspacenlp.com/api/admin/drive/rename'),
          headers: {
            'Authorization': 'Bearer ${AuthManager.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'item_id': int.tryParse(item.id) ?? item.id,
            'item_type': item.isFolder ? 'folder' : 'file',
            'new_name': newName,
          }),
        );
        if (!mounted) return;
        if (response.statusCode == 200) {
          AppToast.showSuccess(context, 'Renamed to "$newName"');
          _fetchFolderContents();
        } else {
          AppToast.showError(
            context,
            ErrorHelper.getFriendlyMessage(null, response.statusCode),
          );
        }
      } catch (e) {
        if (!mounted) return;
        AppToast.showError(context, ErrorHelper.getFriendlyMessage(e));
      }
    }
  }

  Widget _buildItemGridOrList(List<FileModel> items) {
    if (_isGridView) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          return RepaintBoundary(
            child: FileCard(
              file: item,
              isGrid: true,
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedFileIds.contains(item.id),
              onLongPress: () => _enterSelectionMode(item),
              onMenuSelected: (action) {
                if (action == 'rename') {
                  _showRenameDialog(item);
                } else if (action == 'delete') {
                  _showDeleteConfirmationDialog(item);
                } else if (action == 'share') {
                  _showShareDialog([item.id]);
                } else if (action == 'move') {
                  _showMoveDialog([item.id]);
                } else if (action == 'download') {
                  _handleDownloadAction(item);
                } else if (action == 'delete_offline' ||
                    action == 'remove_partial') {
                  _handleDeleteOfflineAction(item);
                }
              },
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(item);
                } else if (item.isFolder) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderViewPage(folder: item),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FileDetailsPage(file: item),
                    ),
                  );
                }
              },
            ),
          );
        }, childCount: items.length),
      );
    } else {
      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          return RepaintBoundary(
            child: FileCard(
              file: item,
              isGrid: false,
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedFileIds.contains(item.id),
              onLongPress: () => _enterSelectionMode(item),
              onMenuSelected: (action) {
                if (action == 'rename') {
                  _showRenameDialog(item);
                } else if (action == 'delete') {
                  _showDeleteConfirmationDialog(item);
                } else if (action == 'share') {
                  _showShareDialog([item.id]);
                } else if (action == 'move') {
                  _showMoveDialog([item.id]);
                } else if (action == 'download') {
                  _handleDownloadAction(item);
                } else if (action == 'delete_offline' ||
                    action == 'remove_partial') {
                  _handleDeleteOfflineAction(item);
                }
              },
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(item);
                } else if (item.isFolder) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderViewPage(folder: item),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FileDetailsPage(file: item),
                    ),
                  );
                }
              },
            ),
          );
        }, childCount: items.length),
      );
    }
  }
}
