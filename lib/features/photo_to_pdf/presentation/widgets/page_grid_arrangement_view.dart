import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';

class PageGridArrangementView extends StatelessWidget {
  final List<PhotoItem> photos;
  final PdfPhotoLayout layout;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(PhotoItem item) onRotate;
  final void Function(PhotoItem item) onFlipHorizontal;
  final void Function(PhotoItem item) onFilterTap;
  final void Function(PhotoItem item) onDelete;

  const PageGridArrangementView({
    super.key,
    required this.photos,
    required this.layout,
    required this.onReorder,
    required this.onRotate,
    required this.onFlipHorizontal,
    required this.onFilterTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photosPerPage = layout.photosPerPage;
    final totalPages = (photos.length / photosPerPage).ceil();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 90, left: 16, right: 16),
      itemCount: totalPages > 0 ? totalPages : 1,
      itemBuilder: (context, pageIndex) {
        final startIndex = pageIndex * photosPerPage;
        final endIndex = (startIndex + photosPerPage > photos.length)
            ? photos.length
            : startIndex + photosPerPage;
        final pagePhotos = photos.sublist(startIndex, endIndex);
        final emptySlotsCount = photosPerPage - pagePhotos.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'PDF Page ${pageIndex + 1} of $totalPages',
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${pagePhotos.length}/$photosPerPage Slots',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Page Slot Layout
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildLayoutSlots(
                  context: context,
                  pagePhotos: pagePhotos,
                  startIndex: startIndex,
                  emptySlotsCount: emptySlotsCount,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayoutSlots({
    required BuildContext context,
    required List<PhotoItem> pagePhotos,
    required int startIndex,
    required int emptySlotsCount,
    required bool isDark,
  }) {
    final allSlotWidgets = <Widget>[];

    for (int i = 0; i < pagePhotos.length; i++) {
      final item = pagePhotos[i];
      final globalIndex = startIndex + i;
      allSlotWidgets.add(
        _buildFilledSlot(
          context: context,
          item: item,
          globalIndex: globalIndex,
          isDark: isDark,
        ),
      );
    }

    for (int i = 0; i < emptySlotsCount; i++) {
      allSlotWidgets.add(_buildEmptyDashedSlot(context: context, isDark: isDark));
    }

    switch (layout) {
      case PdfPhotoLayout.onePerPage:
        return SizedBox(
          height: 240,
          child: allSlotWidgets[0],
        );

      case PdfPhotoLayout.twoPerPageStacked:
        return Column(
          children: [
            SizedBox(height: 140, child: allSlotWidgets[0]),
            const SizedBox(height: 8),
            SizedBox(height: 140, child: allSlotWidgets[1]),
          ],
        );

      case PdfPhotoLayout.twoPerPageSideBySide:
        return Row(
          children: [
            Expanded(child: SizedBox(height: 180, child: allSlotWidgets[0])),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 180, child: allSlotWidgets[1])),
          ],
        );

      case PdfPhotoLayout.threePerPage:
        return Column(
          children: [
            SizedBox(height: 110, child: allSlotWidgets[0]),
            const SizedBox(height: 8),
            SizedBox(height: 110, child: allSlotWidgets[1]),
            const SizedBox(height: 8),
            SizedBox(height: 110, child: allSlotWidgets[2]),
          ],
        );

      case PdfPhotoLayout.fourPerPageGrid:
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: SizedBox(height: 130, child: allSlotWidgets[0])),
                const SizedBox(width: 8),
                Expanded(child: SizedBox(height: 130, child: allSlotWidgets[1])),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: SizedBox(height: 130, child: allSlotWidgets[2])),
                const SizedBox(width: 8),
                Expanded(child: SizedBox(height: 130, child: allSlotWidgets[3])),
              ],
            ),
          ],
        );

      case PdfPhotoLayout.sixPerPageGrid:
        return Column(
          children: [
            for (int r = 0; r < 3; r++) ...[
              Row(
                children: [
                  Expanded(child: SizedBox(height: 100, child: allSlotWidgets[r * 2])),
                  const SizedBox(width: 8),
                  Expanded(child: SizedBox(height: 100, child: allSlotWidgets[r * 2 + 1])),
                ],
              ),
              if (r < 2) const SizedBox(height: 8),
            ],
          ],
        );
    }
  }

  Widget _buildFilledSlot({
    required BuildContext context,
    required PhotoItem item,
    required int globalIndex,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo preview with transforms
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
                  ? Image.memory(item.cachedBytes!, fit: BoxFit.cover)
                  : Image.file(File(item.path), fit: BoxFit.cover),
            ),
          ),

          // Photo Index Badge
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${globalIndex + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Quick Action Overlay
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniAction(
                    icon: Icons.rotate_right_rounded,
                    tooltip: 'Rotate',
                    onTap: () => onRotate(item),
                  ),
                  _buildMiniAction(
                    icon: Icons.auto_fix_high_rounded,
                    tooltip: 'Filter',
                    onTap: () => onFilterTap(item),
                  ),
                  _buildMiniAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Remove',
                    color: AppColors.error,
                    onTap: () => onDelete(item),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  /// Visually indicates empty slots on partially filled pages with dashed border & blank white area
  Widget _buildEmptyDashedSlot({
    required BuildContext context,
    required bool isDark,
  }) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: isDark
            ? AppColors.textSecondaryDark.withValues(alpha: 0.35)
            : Colors.grey.shade400,
        dashWidth: 5,
        dashSpace: 4,
        strokeWidth: 1.5,
        borderRadius: 12,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.crop_free_rounded,
                size: 22,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(height: 4),
              Text(
                'Blank Slot',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  _DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 5.0,
    this.dashSpace = 4.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = distance + dashWidth;
        final extractPath = metric.extractPath(
          distance,
          nextDistance > metric.length ? metric.length : nextDistance,
        );
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth;
  }
}
