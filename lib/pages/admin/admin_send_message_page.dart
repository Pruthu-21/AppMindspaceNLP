import 'package:flutter/material.dart';
import '../../services/message_service.dart';

class AdminSendMessagePage extends StatefulWidget {
  final String adminToken;

  const AdminSendMessagePage({Key? key, required this.adminToken}) : super(key: key);

  @override
  State<AdminSendMessagePage> createState() => _AdminSendMessagePageState();
}

class _AdminSendMessagePageState extends State<AdminSendMessagePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _attachmentUrlController = TextEditingController();
  bool _isSending = false;

  final MessageService _messageService = MessageService();

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    final success = await _messageService.sendAdminMessage(
      adminToken: widget.adminToken,
      title: _titleController.text,
      body: _bodyController.text,
      attachmentUrl: _attachmentUrlController.text,
    );

    setState(() {
      _isSending = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully!')),
        );
        Navigator.pop(context); // Go back after sending
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Message to Users'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Message Title'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Message Body'),
                maxLines: 4,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Body is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _attachmentUrlController,
                decoration: const InputDecoration(
                  labelText: 'Attachment URL (Optional)',
                  hintText: 'e.g. https://youtube.com/...',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSending ? null : _sendMessage,
                child: _isSending
                    ? const CircularProgressIndicator()
                    : const Text('Send Broadcast Message'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
