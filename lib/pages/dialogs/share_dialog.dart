import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_manager.dart';

class ShareDialog extends StatefulWidget {
  final List<String> fileIds;

  const ShareDialog({super.key, required this.fileIds});

  static Future<List<int>?> show(BuildContext context, List<String> fileIds) {
    return showDialog<List<int>>(
      context: context,
      builder: (context) => ShareDialog(fileIds: fileIds),
    );
  }

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  List<dynamic> _usersList = [];
  bool _isFetchingUsers = true;
  final Set<int> _selectedUserIds = {};
  String _searchUserQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _fetchUsersAndShared();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsersAndShared() async {
    final futures = <Future<http.Response>>[
      http.get(
        Uri.parse('https://mindspacenlp.com/api/drive/users'),
        headers: {
          'Authorization': 'Bearer ${AuthManager.token}',
          'Accept': 'application/json',
        },
      ),
    ];

    if (widget.fileIds.isNotEmpty) {
      futures.add(
        http.get(
          Uri.parse(
            'https://mindspacenlp.com/api/drive/file/${widget.fileIds.first}/shared-users',
          ),
          headers: {
            'Authorization': 'Bearer ${AuthManager.token}',
            'Accept': 'application/json',
          },
        ),
      );
    }

    try {
      final responses = await Future.wait(futures);

      if (responses.isNotEmpty && responses[0].statusCode == 200) {
        final decoded = jsonDecode(responses[0].body);
        final data = decoded['data'] ?? (decoded is List ? decoded : []);
        _usersList = data is List ? data : [];
      }

      if (responses.length > 1 && responses[1].statusCode == 200) {
        final decodedShared = jsonDecode(responses[1].body);
        final List<dynamic> sharedData = decodedShared is List
            ? decodedShared
            : (decodedShared['data'] is List ? decodedShared['data'] : []);

        for (var su in sharedData) {
          final int sId = int.tryParse(su['id']?.toString() ?? '') ?? 0;
          if (sId > 0) _selectedUserIds.add(sId);
        }
      }
    } catch (e) {
      debugPrint('Share dialog fetch error: $e');
    }

    if (mounted) {
      setState(() {
        _isFetchingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _usersList.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final q = _searchUserQuery.trim().toLowerCase();
      return q.isEmpty || name.contains(q) || email.contains(q);
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Share ${widget.fileIds.length} Item(s)'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchUserQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search user by name or email...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isFetchingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : (filteredUsers.isEmpty
                        ? const Center(child: Text('No matching users found.'))
                        : ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, idx) {
                              final u = filteredUsers[idx];
                              final int uId =
                                  int.tryParse(u['id']?.toString() ?? '') ?? 0;
                              final bool isChecked = _selectedUserIds.contains(
                                uId,
                              );

                              return CheckboxListTile(
                                title: Text(u['name'] ?? 'Unknown User'),
                                subtitle: Text(u['email'] ?? ''),
                                value: isChecked,
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() {
                                    if (val) {
                                      _selectedUserIds.add(uId);
                                    } else {
                                      _selectedUserIds.remove(uId);
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _selectedUserIds.toList());
          },
          child: const Text('Share'),
        ),
      ],
    );
  }
}
