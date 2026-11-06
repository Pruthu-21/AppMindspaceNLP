import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/message_service.dart';

class MessagesPage extends StatefulWidget {
  final String userToken;

  const MessagesPage({super.key, required this.userToken});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final MessageService _messageService = MessageService();
  late Future<List<AppMessage>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _messageService.fetchMessages(widget.userToken);
  }

  IconData _getIconForUrl(String url) {
    url = url.toLowerCase();
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return Icons.video_library;
    } else if (url.contains('maps.google.com') || url.contains('goo.gl/maps')) {
      return Icons.map;
    } else if (url.contains('facebook.com')) {
      return Icons.facebook;
    } else if (url.contains('instagram.com')) {
      return Icons.camera_alt;
    } else {
      return Icons.link;
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri? url = Uri.tryParse(urlString);
    if (url == null || (url.scheme != 'http' && url.scheme != 'https')) {
      return;
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $urlString')));
      }
    }
  }

  void _showReportIssueDialog() {
    final outerContext = context;
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report an Issue'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        hintText: 'e.g. Cannot download file',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Describe the problem...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isSubmitting)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          final subject = subjectController.text.trim();
                          final message = messageController.text.trim();
                          if (subject.isEmpty || message.isEmpty) return;

                          setState(() {
                            isSubmitting = true;
                          });

                          final success = await _messageService.sendReportIssue(
                            userToken: widget.userToken,
                            subject: subject,
                            message: message,
                          );

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          if (!outerContext.mounted) return;
                          ScaffoldMessenger.of(outerContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Issue reported successfully!'
                                    : 'Failed to report issue',
                              ),
                              backgroundColor: success
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );
                        },
                        child: const Text('Submit'),
                      ),
              ],
            );
          },
        );
      },
    ).then((_) {
      subjectController.dispose();
      messageController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportIssueDialog,
        icon: const Icon(Icons.bug_report),
        label: const Text('Report Issue'),
      ),
      body: FutureBuilder<List<AppMessage>>(
        future: _messagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading messages'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No messages'));
          }

          final messages = snapshot.data!;
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinkifiedText(text: msg.body, onLaunch: _launchUrl),
                      if (msg.attachmentUrl != null &&
                          msg.attachmentUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _launchUrl(msg.attachmentUrl!),
                          icon: Icon(_getIconForUrl(msg.attachmentUrl!)),
                          label: const Text('Open Attachment'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        '${msg.createdAt.year}-${msg.createdAt.month.toString().padLeft(2, '0')}-${msg.createdAt.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class LinkifiedText extends StatefulWidget {
  final String text;
  final Function(String) onLaunch;

  const LinkifiedText({super.key, required this.text, required this.onLaunch});

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<dynamic> _spans = [];

  @override
  void initState() {
    super.initState();
    _parseText();
  }

  @override
  void didUpdateWidget(LinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _parseText();
    }
  }

  void _parseText() {
    _spans.clear();
    final RegExp urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final matches = urlRegex.allMatches(widget.text);

    int currentPosition = 0;
    for (final match in matches) {
      if (match.start > currentPosition) {
        _spans.add(widget.text.substring(currentPosition, match.start));
      }
      _spans.add(Uri.parse(match.group(0)!));
      currentPosition = match.end;
    }

    if (currentPosition < widget.text.length) {
      _spans.add(widget.text.substring(currentPosition));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: _spans.map((span) {
          if (span is String) {
            return TextSpan(
              text: span,
              style: DefaultTextStyle.of(context).style,
            );
          } else if (span is Uri) {
            final urlString = span.toString();
            return WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => widget.onLaunch(urlString),
                child: Text(
                  urlString,
                  style: DefaultTextStyle.of(context).style.copyWith(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            );
          }
          return const TextSpan();
        }).toList(),
      ),
    );
  }
}
