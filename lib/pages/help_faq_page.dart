import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../widgets/buttons.dart';

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help & FAQ Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Header Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How can we help you today?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Browse frequently asked questions regarding offline sync, storage capacities and account security.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Frequently Asked Questions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Accordion FAQs
              _buildFaqItem(
                context,
                question: 'How do I make a file available offline?',
                answer: 'Navigate to any file details page and click the "Save Offline" button. The app will download the file to your secure local cache. Alternatively, tap the three dots next to any file in your lists and choose "Make Offline". Once saved, a green badge appears on the file.',
              ),
              const SizedBox(height: 12),
              _buildFaqItem(
                context,
                question: 'How does background synchronization work?',
                answer: 'If you open a document while offline, the app records an access log on your device. The moment your device goes back online, a background timer automatically detects internet access and uploads these pending logs to the servers, ensuring analytics and file progress indicators stay up-to-date silently.',
              ),
              const SizedBox(height: 12),
              _buildFaqItem(
                context,
                question: 'How do I share files with other users?',
                answer: 'If you are an Administrator, you can share files with other team members. Click the three-dot action menu on any file card, choose "Share", and select the target users from your group list to grant them access instantly.',
              ),
              const SizedBox(height: 12),
              _buildFaqItem(
                context,
                question: 'How do I remove an offline copy from my phone?',
                answer: 'Simply tap the red "Delete Offline File" button on the file details page or select the red "Delete Offline File" option in the three-dot bottom popup menu. This will safely wipe the cached file from your storage and free up space.',
              ),
              const SizedBox(height: 12),
              _buildFaqItem(
                context,
                question: 'Why does Google Login fail sometimes?',
                answer: 'Make sure your Android or iOS device is connected to the internet and Google Play Services are running properly. Google signatures require package registration in Google Console. If issues persist, try standard email login.',
              ),
              const SizedBox(height: 28),

              // Contact Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.forum_rounded, color: AppColors.primary, size: 36),
                    const SizedBox(height: 12),
                    const Text(
                      'Still need help?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'If you could not find the answers to your questions, please drop our operations team a message.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      text: 'Contact Team Mindspace NLP',
                      icon: Icons.phone_rounded,
                      onPressed: () async {
                        final Uri launchUri = Uri(
                          scheme: 'tel',
                          path: '+918000002265',
                        );
                        try {
                          if (await canLaunchUrl(launchUri)) {
                            await launchUrl(launchUri);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open phone dialer.')),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error launching dialer: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, {required String question, required String answer}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          collapsedIconColor: isDark ? Colors.white60 : Colors.black45,
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
