import 'package:flutter/material.dart';
import '../../models/file_model.dart';

class MoveDialog extends StatefulWidget {
  final int itemCount;
  final List<FileModel> availableFolders;

  const MoveDialog({
    super.key,
    required this.itemCount,
    required this.availableFolders,
  });

  /// Returns folder ID. Returns -1 for Root. Returns null if canceled.
  static Future<int?> show(
    BuildContext context,
    int itemCount,
    List<FileModel> availableFolders,
  ) {
    return showDialog<int>(
      context: context,
      builder: (context) =>
          MoveDialog(itemCount: itemCount, availableFolders: availableFolders),
    );
  }

  @override
  State<MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<MoveDialog> {
  String? _selectedTargetFolderId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Move ${widget.itemCount} Item(s) to...'),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(
                Icons.folder_special_rounded,
                color: Colors.blue,
                size: 28,
              ),
              title: const Text(
                'Root Directory ( / )',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                'Main location',
                style: TextStyle(fontSize: 12),
              ),
              trailing: _selectedTargetFolderId == null
                  ? const Icon(Icons.check_circle_rounded, color: Colors.blue)
                  : const Icon(Icons.circle_outlined, color: Colors.grey),
              onTap: () {
                setState(() {
                  _selectedTargetFolderId = null;
                });
              },
            ),
            const Divider(),
            if (widget.availableFolders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No other folders available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...widget.availableFolders.map((folder) {
                final isSelected = _selectedTargetFolderId == folder.id;
                return ListTile(
                  leading: Icon(
                    Icons.folder_rounded,
                    color: Colors.amber.shade600,
                    size: 28,
                  ),
                  title: Text(
                    folder.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Folder',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.blue,
                        )
                      : const Icon(Icons.circle_outlined, color: Colors.grey),
                  onTap: () {
                    setState(() {
                      _selectedTargetFolderId = folder.id;
                    });
                  },
                );
              }),
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
            if (_selectedTargetFolderId == null) {
              Navigator.pop(context, -1); // -1 signifies Root
            } else {
              Navigator.pop(
                context,
                int.tryParse(_selectedTargetFolderId!) ?? -1,
              );
            }
          },
          child: const Text('Move'),
        ),
      ],
    );
  }
}
