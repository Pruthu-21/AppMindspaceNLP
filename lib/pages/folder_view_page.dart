import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../constants/app_colors.dart';
import '../models/file_model.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/file_card.dart';
import '../widgets/empty_widget.dart';
import '../services/auth_manager.dart';
import '../services/role_manager.dart';
import '../widgets/app_toast.dart';
import 'file_details_page.dart';
import '../services/download_service.dart';

class FolderViewPage extends StatefulWidget {
  final FileModel folder;

  const FolderViewPage({Key? key, required this.folder}) : super(key: key);

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
      final response = await http.get(
        Uri.parse('https://mindspacenlp.com/api/drive/folder/${widget.folder.id}/contents'),
        headers: {
          'Authorization': 'Bearer ${AuthManager.token}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
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

        final parsedFolders = rawFolders.map((item) {
          return FileModel(
            id: (item['id'] ?? DateTime.now().millisecondsSinceEpoch).toString(),
            name: (item['name'] ?? 'Untitled Folder').toString(),
            format: 'folder',
            sizeBytes: 0,
            uploadDate: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
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
            ownerName: item['owner'] ?? 'Admin',
            previewUrl: url,
          );
        }).toList();

        final List<FileModel> updatedFiles = [];
        for (var file in parsedFiles) {
          final isDl = await DownloadService.isFileDownloaded(file.name);
          if (isDl) {
            final localPath = await DownloadService.getLocalFilePath(file.name);
            updatedFiles.add(FileModel(
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
    } catch (_) {
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
          : _allSubItems.where((f) => f.name.toLowerCase().contains(q)).toList();
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
        if (mounted) AppToast.showInfo(context, 'Uploading file(s) into "${widget.folder.name}"...');

        final uri = Uri.parse('https://mindspacenlp.com/api/admin/drive/upload');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer ${AuthManager.token}';
        request.headers['Accept'] = 'application/json';
        request.fields['folder_id'] = widget.folder.id;

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
          if (mounted) AppToast.showSuccess(context, 'Uploaded successfully!');
          await _fetchFolderContents();
        } else {
          if (mounted) AppToast.showError(context, 'Upload failed (${response.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Upload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = RoleManager.isAdmin;
    final isDark = theme.brightness == Brightness.dark;

    final subFolders = _filteredItems.where((f) => f.isFolder).toList();
    final subFiles = _filteredItems.where((f) => !f.isFolder).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.folder_rounded, color: Colors.amber.shade600, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.folder.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
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
                      ? const Center(child: CircularProgressIndicator())
                      : (_filteredItems.isEmpty
                          ? const EmptyWidget(
                              icon: Icons.folder_open_rounded,
                              title: 'Folder is Empty',
                              description: 'No files or subfolders found inside this folder.',
                            )
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              children: [
                                if (subFolders.isNotEmpty) ...[
                                  Text(
                                    'Folders (${subFolders.length})',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildItemGridOrList(subFolders),
                                  const SizedBox(height: 16),
                                ],
                                if (subFiles.isNotEmpty) ...[
                                  Text(
                                    'Files (${subFiles.length})',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
              icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
              label: const Text('Add File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      bottomNavigationBar: _isSelectionMode
          ? _buildMultiSelectBottomBar(context, theme, isDark)
          : null,
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedFileIds.clear();
      _isSelectionMode = false;
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
                  await _fetchFolderContents();
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

  void _showDeleteConfirmationDialog(FileModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${item.isFolder ? "Folder" : "File"}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
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
                  if (mounted) AppToast.showSuccess(context, '"${item.name}" deleted successfully.');
                  await _fetchFolderContents();
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
                        await _fetchFolderContents();
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

  void _showMoveDialog(List<String> selectedIds) async {
    if (selectedIds.isEmpty) return;

    List<String> fileIdsToMove = [];
    List<String> folderIdsToMove = [];

    for (var id in selectedIds) {
      final match = _allSubItems.firstWhere(
        (f) => f.id == id,
        orElse: () => FileModel(id: id, name: '', format: '', sizeBytes: 0, uploadDate: DateTime.now(), ownerName: ''),
      );
      if (match.isFolder) {
        folderIdsToMove.add(id);
      } else {
        fileIdsToMove.add(id);
      }
    }

    // Fetch folders dynamically from my-drive to show as targets
    List<FileModel> availableFolders = [];
    try {
      final res = await http.get(
        Uri.parse('https://mindspacenlp.com/api/drive/my-drive'),
        headers: {
          'Authorization': 'Bearer ${AuthManager.token}',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List<dynamic> data = decoded['data'] ?? decoded['files'] ?? [];
        availableFolders = data
            .map((item) {
              final isFolder = item['is_folder'] == true || item['mime_type'] == 'folder';
              if (isFolder) {
                return FileModel(
                  id: (item['id'] ?? '').toString(),
                  name: (item['name'] ?? 'Untitled Folder').toString(),
                  format: 'folder',
                  sizeBytes: 0,
                  uploadDate: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
                  ownerName: item['owner'] ?? 'Admin',
                );
              }
              return null;
            })
            .whereType<FileModel>()
            .where((f) => !folderIdsToMove.contains(f.id))
            .toList();
      }
    } catch (_) {}

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
                        AppToast.showSuccess(context, 'Items moved successfully!');
                        await _fetchFolderContents();
                      } else {
                        AppToast.showError(context, 'Move failed (${response.statusCode})');
                      }
                    } catch (e) {
                      AppToast.showError(context, 'Move error: $e');
                    }
                  },
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleDownloadAction(FileModel file) async {
    if (file.isFolder) return;
    final isCurrentlyDownloaded = file.isDownloaded;
    if (isCurrentlyDownloaded) {
      await DownloadService.deleteDownloadedFile(file.name);
      if (mounted) {
        AppToast.showInfo(context, '"${file.name}" removed from offline storage.');
        await _fetchFolderContents();
      }
    } else {
      AppToast.showInfo(context, 'Saving "${file.name}" to local device storage...');
      final url = file.previewUrl ?? '';
      final ok = await DownloadService.downloadFile(url, file.name, model: file);
      if (ok) {
        if (mounted) {
          AppToast.showSuccess(context, '"${file.name}" saved locally for offline access!');
          await _fetchFolderContents();
        }
      } else {
        if (mounted) {
          final error = DownloadService.downloadErrorNotifier.value ?? 'Failed to download "${file.name}". Please check internet connection.';
          AppToast.showError(context, error);
        }
      }
    }
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

  void _showRenameDialog(FileModel item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename ${item.isFolder ? "Folder" : "File"}'),
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
              if (newName.isNotEmpty && newName != item.name) {
                Navigator.pop(context);
                try {
                  final response = await http.post(
                    Uri.parse('https://mindspacenlp.com/api/drive/rename'),
                    headers: {
                      'Authorization': 'Bearer ${AuthManager.token}',
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                    },
                    body: jsonEncode({
                      'item_id': int.tryParse(item.id) ?? item.id,
                      'item_type': item.isFolder ? 'folder' : 'file',
                      'new_name': newName,
                    }),
                  );
                  if (response.statusCode == 200) {
                    if (mounted) AppToast.showSuccess(context, 'Renamed to "$newName"');
                    await _fetchFolderContents();
                  } else {
                    if (mounted) AppToast.showError(context, 'Rename failed (${response.statusCode})');
                  }
                } catch (e) {
                  if (mounted) AppToast.showError(context, 'Rename error: $e');
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemGridOrList(List<FileModel> items) {
    if (_isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return FileCard(
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
              }
            },
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item);
              } else if (item.isFolder) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FolderViewPage(folder: item)),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FileDetailsPage(file: item)),
                );
              }
            },
          );
        },
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return FileCard(
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
              }
            },
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item);
              } else if (item.isFolder) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FolderViewPage(folder: item)),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FileDetailsPage(file: item)),
                );
              }
            },
          );
        },
      );
    }
  }
}
