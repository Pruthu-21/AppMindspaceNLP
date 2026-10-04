import 'package:flutter/material.dart';
import '../../models/file_model.dart';
import '../../constants/app_colors.dart';

class RenameDialog extends StatefulWidget {
  final FileModel file;

  const RenameDialog({super.key, required this.file});

  static Future<String?> show(BuildContext context, FileModel file) {
    return showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(file: file),
    );
  }

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.file.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Rename Item'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Enter new name'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
        ),
        ElevatedButton(
          onPressed: () {
            final newName = _controller.text.trim();
            if (newName.isNotEmpty && newName != widget.file.name) {
              Navigator.pop(context, newName);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}
