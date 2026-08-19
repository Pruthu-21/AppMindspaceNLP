import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/auth_manager.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/buttons.dart';

class AdminUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String initials;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.initials,
  });
}

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({Key? key}) : super(key: key);

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  List<AdminUser> _users = [];
  List<AdminUser> _filteredUsers = [];
  String _searchQuery = '';
  bool _isLoading = false;

  String _totalUsersCount = '...';
  String _totalFilesCount = '...';
  String _totalStorageUsed = '...';

  @override
  void initState() {
    super.initState();
    _fetchAdminUsers();
  }

  Future<void> _fetchAdminUsers() async {
    if (AuthManager.token == null || AuthManager.token!.startsWith('google_token_')) return;
    setState(() { _isLoading = true; });

    try {
      final response = await http.get(
        Uri.parse('https://mindspacenlp.com/api/admin/users'),
        headers: {
          'Authorization': 'Bearer ${AuthManager.token}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        final List<AdminUser> loaded = data.map((item) {
          final String name = (item['name'] ?? 'User').toString();
          final String email = (item['email'] ?? '').toString();
          final String roleStr = (item['role'] ?? 'user').toString();
          final initials = name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase();

          return AdminUser(
            id: (item['id'] ?? '1').toString(),
            name: name,
            email: email,
            role: roleStr.toLowerCase() == 'admin' ? 'Administrator' : 'Standard User',
            initials: initials.isEmpty ? 'U' : initials,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _users = loaded;
            _onSearchChanged(_searchQuery);
            if (body['stats'] != null) {
              final stats = body['stats'];
              _totalUsersCount = (stats['total_users'] ?? loaded.length).toString();
              _totalFilesCount = (stats['total_files'] ?? '0').toString();
              _totalStorageUsed = (stats['total_storage'] ?? '0 B').toString();
            } else {
              _totalUsersCount = loaded.length.toString();
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.trim().isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users
            .where((u) => u.name.toLowerCase().contains(query.toLowerCase()) ||
                          u.email.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showChangePasswordDialog(AdminUser user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reset User Password',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For: ${user.name}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'New Password',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscureNewPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Must be at least 6 characters';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter new password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setModalState(() {
                                obscureNewPassword = !obscureNewPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Confirm Password',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm password';
                          }
                          if (value != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Re-enter new password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setModalState(() {
                                obscureConfirmPassword = !obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newPassword = passwordController.text.trim();
                      try {
                        final res = await http.post(
                          Uri.parse('https://mindspacenlp.com/api/admin/users/${user.id}/change-password'),
                          headers: {
                            'Authorization': 'Bearer ${AuthManager.token}',
                            'Content-Type': 'application/json',
                            'Accept': 'application/json',
                          },
                          body: jsonEncode({'new_password': newPassword}),
                        );

                        if (context.mounted) Navigator.pop(context);

                        if (res.statusCode == 200) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Password updated successfully for ${user.name}.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not update password (${res.statusCode})'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update password: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // TODO: API Integration Here - Refresh administration logs & user statuses.
            await Future.delayed(const Duration(seconds: 1));
          },
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Dashboard header
              Text(
                'Admin Console',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'System stats & user directory controls',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Quick Analytics Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard('Active Users', _totalUsersCount, Icons.people_outline_rounded, AppColors.primary),
                  _buildStatCard('Total Files', _totalFilesCount, Icons.insert_drive_file_outlined, AppColors.secondary),
                  _buildStatCard('Total Storage', _totalStorageUsed, Icons.storage_rounded, AppColors.accent),
                  _buildStatCard('Server Status', 'Operational', Icons.dns_outlined, AppColors.success),
                ],
              ),
              const SizedBox(height: 24),

              // Upload Activity Chart Card
              _buildUploadActivityCard(),
              const SizedBox(height: 24),

              // Users list section header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'User Accounts (${_filteredUsers.length})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Provision user triggered (UI only)')),
                      );
                    },
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('Add User', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // User Search
              SearchBarWidget(
                hintText: 'Search users by name or email',
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 16),

              // Users List cards
              if (_filteredUsers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: Text('No users match search.')),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final avatarColor = _getAvatarColor(user.name);
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: avatarColor.withOpacity(0.12),
                            child: Text(
                              user.initials,
                              style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (user.role != 'Standard User') ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'ADMIN',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.email,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.key_rounded, color: theme.colorScheme.primary, size: 20),
                            tooltip: 'Reset Password',
                            onPressed: () => _showChangePasswordDialog(user),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color accentColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              Icon(icon, color: accentColor, size: 20),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadActivityCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Simulated weekly graph data (Mon to Sun) heights
    final List<double> weeklyData = [45, 78, 60, 110, 52, 90, 65];
    final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Traffic',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Daily volume statistics (GB)',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '+12.4% vs last week',
                  style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Custom Bar Graph Chart
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(weeklyData.length, (idx) {
                final height = weeklyData[idx];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        width: 14,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                        height: height,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[idx],
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.info,
      AppColors.success,
      Colors.deepOrange,
      Colors.pink,
      Colors.purple,
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}
