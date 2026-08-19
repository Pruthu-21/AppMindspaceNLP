import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/file_model.dart';
import '../services/role_manager.dart';
import '../services/download_service.dart';

class FileCard extends StatelessWidget {
  final FileModel file;
  final bool isGrid;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenuPressed;
  final Function(String action)? onMenuSelected;
  final bool isSelectionMode;
  final bool isSelected;

  const FileCard({
    Key? key,
    required this.file,
    required this.isGrid,
    required this.onTap,
    this.onLongPress,
    this.onMenuPressed,
    this.onMenuSelected,
    this.isSelectionMode = false,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isGrid ? _buildGridCard(context) : _buildListCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected 
              ? theme.colorScheme.primary.withOpacity(0.12)
              : (isDark ? AppColors.surfaceDark : Colors.white),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIconWithBadge(context),
                if (isSelectionMode)
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? theme.colorScheme.primary : Colors.grey,
                    size: 22,
                  )
                else
                  _buildThreeDotButton(context),
              ],
            ),
            const Spacer(),
            Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            if (file.downloadStatus == 'completed') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    file.isFolder ? 'Folder' : file.sizeString,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  Row(
                    children: [
                      if (file.isPinned)
                        Icon(Icons.push_pin_rounded, size: 10, color: theme.colorScheme.primary),
                      if (file.isFavorite) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
                      ],
                      if (file.isDownloaded) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.offline_pin_rounded, size: 12, color: AppColors.accent),
                      ],
                    ],
                  ),
                ],
              ),
            ] else ...[
              _buildProgressBar(context, true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected 
              ? theme.colorScheme.primary.withOpacity(0.12)
              : (isDark ? AppColors.surfaceDark : Colors.white),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? theme.colorScheme.primary : Colors.grey,
                  size: 24,
                ),
              ),
            _buildIconWithBadge(context),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (file.downloadStatus == 'completed') ...[
                    Row(
                      children: [
                        Text(
                          file.isFolder ? 'Folder' : file.sizeString,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(file.uploadDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    _buildProgressBar(context, false),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                if (file.isPinned)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.push_pin_rounded, size: 14, color: theme.colorScheme.primary),
                  ),
                if (file.isFavorite)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                  ),
                if (file.isDownloaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.offline_pin_rounded, size: 16, color: AppColors.accent),
                  ),
              ],
            ),
            if (!isSelectionMode) _buildThreeDotButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(BuildContext context) {
    final isImg = ['image', 'png', 'jpg', 'jpeg', 'webp', 'gif'].contains(file.format.toLowerCase());
    if (isImg && file.previewUrl != null && file.previewUrl!.isNotEmpty) {
      return Hero(
        tag: 'hero-icon-${file.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            file.previewUrl!,
            width: isGrid ? 40 : 44,
            height: isGrid ? 40 : 44,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultBox(context, Icons.image_rounded, AppColors.info),
          ),
        ),
      );
    }

    IconData icon;
    Color color;

    switch (file.format) {
      case 'folder':
        icon = Icons.folder_rounded;
        color = Colors.amber.shade600;
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf_rounded;
        color = AppColors.error;
        break;
      case 'video':
        icon = Icons.video_library_rounded;
        color = AppColors.secondary;
        break;
      case 'doc':
        icon = Icons.description_rounded;
        color = AppColors.primary;
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        color = Colors.grey;
    }

    return Hero(
      tag: 'hero-icon-${file.id}',
      child: _buildDefaultBox(context, icon, color),
    );
  }

  Widget _buildDefaultBox(BuildContext context, IconData icon, Color color) {
    return Container(
      width: isGrid ? 40 : 44,
      height: isGrid ? 40 : 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: color,
        size: isGrid ? 20 : 22,
      ),
    );
  }

  Widget _buildThreeDotButton(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showSleekActionBottomSheet(context),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: theme.brightness == Brightness.dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  void _showSleekActionBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAdmin = RoleManager.isAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Builder(builder: (context) {
              final isDownloaded = file.isDownloaded || DownloadService.isCompletedInMemory(file.name);
              final isActive = DownloadService.activeDownloadsNotifier.value.contains(file.name);
              final isStopped = file.downloadStatus == 'stopped' && !isDownloaded;
              
              String actionText;
              IconData actionIcon;
              Color? actionColor;
              
              if (isDownloaded) {
                actionText = 'Delete Offline File';
                actionIcon = Icons.delete_outline_rounded;
                actionColor = Colors.red;
              } else if (isActive) {
                actionText = 'Downloading...';
                actionIcon = Icons.downloading_rounded;
                actionColor = theme.colorScheme.primary;
              } else if (isStopped) {
                actionText = 'Resume Download';
                actionIcon = Icons.download_rounded;
                actionColor = theme.colorScheme.primary;
              } else {
                actionText = 'Make Offline';
                actionIcon = Icons.download_rounded;
                actionColor = theme.colorScheme.primary;
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildIconWithBadge(context),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              file.isFolder ? 'Folder' : (file.customSizeString ?? file.sizeString),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  ListTile(
                    leading: Icon(actionIcon, color: actionColor),
                    title: Text(
                      actionText,
                      style: TextStyle(
                        color: actionColor,
                        fontWeight: isDownloaded ? FontWeight.bold : null,
                      ),
                    ),
                    onTap: isActive
                        ? null
                        : () {
                            Navigator.pop(context);
                            onMenuSelected?.call('download');
                          },
                  ),
                  if (isActive)
                    ListTile(
                      leading: const Icon(Icons.stop_circle_rounded, color: Colors.red),
                      title: const Text('Stop Download', style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        DownloadService.cancelDownloadFor(file.name);
                      },
                    ),
                  if (isStopped)
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      title: const Text('Remove from Downloads', style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        onMenuSelected?.call('remove_partial');
                      },
                    ),
                  if (isAdmin) ...[
                    ListTile(
                      leading: const Icon(Icons.share_rounded, color: Colors.blue),
                      title: const Text('Share'),
                      onTap: () {
                        Navigator.pop(context);
                        onMenuSelected?.call('share');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.drive_file_move_rounded, color: Colors.amber),
                      title: const Text('Move'),
                      onTap: () {
                        Navigator.pop(context);
                        onMenuSelected?.call('move');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_rounded, color: Colors.teal),
                      title: const Text('Rename'),
                      onTap: () {
                        Navigator.pop(context);
                        onMenuSelected?.call('rename');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_rounded, color: Colors.red),
                      title: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(context);
                        onMenuSelected?.call('delete');
                      },
                    ),
                  ],
                ],
              );
            }),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildIconWithBadge(BuildContext context) {
    // Base icon widget
    final baseIcon = _buildFileIcon(context);
    
    return ValueListenableBuilder<Set<String>>(
      valueListenable: DownloadService.activeDownloadsNotifier,
      builder: (context, activeDownloads, child) {
        final isActive = activeDownloads.contains(file.name);
        if (isActive) {
          return ValueListenableBuilder<double>(
            valueListenable: DownloadService.getProgressNotifierFor(file.name),
            builder: (context, progress, child) {
              return _wrapIconWithProgressAndBadge(context, baseIcon, true, progress, false);
            },
          );
        }
        
        final isDownloading = file.downloadStatus == 'downloading';
        final isDownloaded = file.isDownloaded || DownloadService.isCompletedInMemory(file.name);
        return _wrapIconWithProgressAndBadge(
          context, 
          baseIcon, 
          isDownloading, 
          file.downloadProgress, 
          isDownloaded,
        );
      },
    );
  }

  Widget _wrapIconWithProgressAndBadge(
    BuildContext context, 
    Widget baseIcon, 
    bool isDownloading, 
    double progress, 
    bool isDownloaded,
  ) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        if (isDownloading)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: Colors.black12,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        if (isDownloading)
          Positioned(
            bottom: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (isDownloaded)
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, bool isGrid) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: DownloadService.activeDownloadsNotifier,
      builder: (context, activeDownloads, child) {
        final isActive = activeDownloads.contains(file.name);
        if (isActive) {
          return ValueListenableBuilder<double>(
            valueListenable: DownloadService.getProgressNotifierFor(file.name),
            builder: (context, progress, child) {
              return _buildProgressBarContent(context, isGrid, true, progress);
            },
          );
        }
        
        final isDownloading = file.downloadStatus == 'downloading';
        return _buildProgressBarContent(context, isGrid, isDownloading, file.downloadProgress);
      },
    );
  }

  Widget _buildProgressBarContent(BuildContext context, bool isGrid, bool isDownloading, double progress) {
    final statusText = isDownloading ? (isGrid ? 'Saving...' : 'Downloading...') : 'Stopped';
    final percentText = '${(progress * 100).toStringAsFixed(1)}%';
    
    return Column(
      crossAxisAlignment: isGrid ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isGrid)
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDownloading ? AppColors.primary : Colors.red,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                isDownloading ? 'Downloading...' : 'Stopped ($percentText)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDownloading ? AppColors.primary : Colors.red,
                ),
              ),
            if (!isGrid) const SizedBox(width: 8),
            Text(
              percentText,
              style: TextStyle(
                fontSize: isGrid ? 10 : 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: isGrid ? 3 : 4,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDownloading ? AppColors.primary : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
