import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';

class DraggablePhotoCard extends StatelessWidget {
  final PhotoItem item;
  final int index;
  final VoidCallback onCrop;
  final VoidCallback onRotateCW;
  final VoidCallback onRotateCCW;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onFlipVertical;
  final VoidCallback onFilterTap;
  final VoidCallback onDelete;

  const DraggablePhotoCard({
    super.key,
    required this.item,
    required this.index,
    required this.onCrop,
    required this.onRotateCW,
    required this.onRotateCCW,
    required this.onFlipHorizontal,
    required this.onFlipVertical,
    required this.onFilterTap,
    required this.onDelete,
  });

  void _showEditMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Photo #${index + 1}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.crop_rounded, color: AppColors.primary),
                  title: const Text('Crop (Free, 1:1, 4:3, 16:9)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onCrop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.rotate_right_rounded),
                  title: const Text('Rotate 90° CW'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRotateCW();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.rotate_left_rounded),
                  title: const Text('Rotate 90° CCW'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRotateCCW();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flip_rounded),
                  title: const Text('Flip Horizontal'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onFlipHorizontal();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.swap_vert_rounded),
                  title: const Text('Flip Vertical'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onFlipVertical();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: const Text('Remove Photo', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        onTap: () => _showEditMenu(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Drag handle & index badge
              Column(
                children: [
                  const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Thumbnail Image Preview with rotation & flip transform
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.rotate(
                        angle: item.rotationDegrees * (3.141592653589793 / 180),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(
                            item.isFlippedHorizontally ? -1.0 : 1.0,
                            item.isFlippedVertically ? -1.0 : 1.0,
                            1.0,
                          ),
                          child: item.cachedBytes != null
                              ? Image.memory(
                                  item.cachedBytes!,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(item.path),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      if (item.filter != PhotoFilter.none)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.filter.label.split(' ').first,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Photo Info Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.path.split(Platform.pathSeparator).last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.width}x${item.height} • ${FileUtils.formatBytes(item.originalSizeBytes)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Quick Action Toolbar
                    Row(
                      children: [
                        _buildQuickIconButton(
                          icon: Icons.crop_rounded,
                          tooltip: 'Crop',
                          onTap: onCrop,
                        ),
                        _buildQuickIconButton(
                          icon: Icons.rotate_right_rounded,
                          tooltip: 'Rotate CW',
                          onTap: onRotateCW,
                        ),
                        _buildQuickIconButton(
                          icon: Icons.rotate_left_rounded,
                          tooltip: 'Rotate CCW',
                          onTap: onRotateCCW,
                        ),
                        _buildQuickIconButton(
                          icon: Icons.auto_fix_high_rounded,
                          tooltip: 'Filter',
                          onTap: onFilterTap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                tooltip: 'Remove',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
