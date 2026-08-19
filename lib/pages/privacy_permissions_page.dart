import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../widgets/buttons.dart';

class PrivacyPermissionsPage extends StatelessWidget {
  const PrivacyPermissionsPage({Key? key}) : super(key: key);

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
          'Privacy & Permissions',
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
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
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
                  children: [
                    const Icon(Icons.shield_rounded, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      'Your Privacy is Our Priority',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Learn how Mindspace NLP secures your data and respects your local device permissions.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Permissions Section
              Text(
                'Device Permissions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildPermissionTile(
                context,
                icon: Icons.storage_rounded,
                title: 'Storage & Caching Access',
                description: 'Used to store and preview downloaded documents, PDFs, audio tracks, and videos locally on your device for offline reading.',
                status: 'Granted',
                statusColor: AppColors.success,
              ),
              const SizedBox(height: 12),
              _buildPermissionTile(
                context,
                icon: Icons.account_circle_rounded,
                title: 'Google OAuth Sign-In',
                description: 'We authenticate via Google Secure Authentication. We only access your basic profile info (email and display name) for credentials.',
                status: 'Active',
                statusColor: AppColors.info,
              ),
              const SizedBox(height: 28),

              // Privacy Policy details
              Text(
                'Data Security & Analytics',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  ),
                ),
                child: Column(
                  children: [
                    _buildDataRow(
                      context,
                      title: 'End-to-End Encryption',
                      desc: 'All file uploads, transfers, and metadata are securely encrypted in transit using SSL/TLS and stored on protected cloud servers.',
                    ),
                    const Divider(height: 24),
                    _buildDataRow(
                      context,
                      title: 'Offline Usage Logs',
                      desc: 'We track file open events and duration of usage locally. Once internet connectivity is restored, logs automatically sync to our servers.',
                    ),
                    const Divider(height: 24),
                    _buildDataRow(
                      context,
                      title: 'Zero Third-Party Sharing',
                      desc: 'Mindspace NLP does not sell, lease, or distribute your private documents, storage directories, or emails to third parties.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Contact Team Mindspace NLP Card
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Have privacy concerns?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reach out directly to our security and operations team for any queries regarding data storage or compliance.',
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

  Widget _buildPermissionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String status,
    required Color statusColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, {required String title, required String desc}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
