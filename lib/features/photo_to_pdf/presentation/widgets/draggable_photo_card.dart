import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';

class DraggablePhotoCard extends StatelessWidget {
  final PhotoItem item;
  final int index;
  final VoidCallback onRotate;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onFilterTap;
  final VoidCallback onDelete;

  const DraggablePhotoCard({
    super.key,
    required this.item,
    required this.index,
    required this.onRotate,
    required this.onFlipHorizontal,
    required this.onFilterTap,
    required this.onDelete,
  });

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
                        icon: Icons.rotate_right_rounded,
                        tooltip: 'Rotate 90°',
                        onTap: onRotate,
                      ),
                      _buildQuickIconButton(
                        icon: Icons.flip_rounded,
                        tooltip: 'Flip Horizontal',
                        onTap: onFlipHorizontal,
                      ),
                      _buildQuickIconButton(
                        icon: Icons.auto_fix_high_rounded,
                        tooltip: 'Document Filter',
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
