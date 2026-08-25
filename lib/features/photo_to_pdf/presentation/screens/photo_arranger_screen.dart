import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/widgets/draggable_photo_card.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/widgets/layout_selector.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/widgets/page_grid_arrangement_view.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/screens/page_setup_modal.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/screens/pdf_preview_screen.dart';

class PhotoArrangerScreen extends ConsumerStatefulWidget {
  const PhotoArrangerScreen({super.key});

  @override
  ConsumerState<PhotoArrangerScreen> createState() => _PhotoArrangerScreenState();
}

class _PhotoArrangerScreenState extends ConsumerState<PhotoArrangerScreen> {
  bool _showPageLayoutView = true;

  Future<void> _handleCropPhoto(PhotoItem item) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: item.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: const Color(0xFF160C30),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        final bytes = await File(croppedFile.path).readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null && mounted) {
          await ref.read(photoToPdfProvider.notifier).replacePhotoAfterCrop(
                id: item.id,
                newCroppedPath: croppedFile.path,
                newCroppedBytes: bytes,
                newWidth: decoded.width,
                newHeight: decoded.height,
              );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cropping failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showFilterSheet(BuildContext context, PhotoItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Document Filter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                for (final filter in PhotoFilter.values)
                  ListTile(
                    leading: Icon(
                      item.filter == filter
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: AppColors.primary,
                    ),
                    title: Text(filter.label),
                    onTap: () {
                      ref
                          .read(photoToPdfProvider.notifier)
                          .applyPhotoFilter(item.id, filter);
                      Navigator.pop(ctx);
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.copy_all_rounded, color: AppColors.secondary),
                  title: const Text('Apply selected filter to ALL photos'),
                  onTap: () {
                    ref.read(photoToPdfProvider.notifier).applyFilterToAll(item.filter);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Applied ${item.filter.label} filter to all photos'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPageSetupModal(BuildContext context) {
    final state = ref.read(photoToPdfProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PageSetupModal(
          initialConfig: state.config,
          onSave: (newConfig) {
            ref.read(photoToPdfProvider.notifier).updateConfig(newConfig);
          },
        );
      },
    );
  }

  Future<void> _startPdfGeneration() async {
    final controller = ref.read(photoToPdfProvider.notifier);
    final bytes = await controller.generatePdf();

    if (!mounted) return;

    if (bytes != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PdfPreviewScreen(),
        ),
      );
    } else {
      final error = ref.read(photoToPdfProvider).errorMessage;
      if (error != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error),
                const SizedBox(width: 8),
                Text(
                  'Generation Failed',
                  style: GoogleFonts.sora(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(error),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Dismiss'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startPdfGeneration();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(photoToPdfProvider);
    final controller = ref.read(photoToPdfProvider.notifier);
    final photosPerPage = state.config.layout.photosPerPage;
    final totalPages = (state.photos.length / photosPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrange & Layout'),
        actions: [
          IconButton(
            icon: Icon(
              _showPageLayoutView ? Icons.list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _showPageLayoutView ? 'Switch to List Reorder' : 'Switch to Page Preview',
            onPressed: () => setState(() => _showPageLayoutView = !_showPageLayoutView),
          ),
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo',
            onPressed: state.canUndo ? () => controller.undo() : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'Redo',
            onPressed: state.canRedo ? () => controller.redo() : null,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Page Setup',
            onPressed: () => _showPageSetupModal(context),
          ),
        ],
      ),
      body: state.photos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'All photos removed',
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You currently have 0 photos on the arrangement screen. Tap below to return to the photo picker.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('Return to Photo Picker'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Layout Selector Toolbar (1-per-page, 2-per-page side-by-side, 2-per-page stacked, 3-per-page, 4-per-page grid, 6-per-page)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: LayoutSelector(
                    selectedLayout: state.config.layout,
                    onLayoutSelected: (layout) => controller.updateLayout(layout),
                  ),
                ),

                // Info banner (Page count summary & current layout mode)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${state.photos.length} photos • $totalPages PDF page(s) • ${state.config.layout.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content View: either Page Grid with Dashed Empty Slots or Drag-and-Drop Reorder List
                Expanded(
                  child: _showPageLayoutView
                      ? PageGridArrangementView(
                          photos: state.photos,
                          layout: state.config.layout,
                          onReorder: controller.reorderPhotos,
                          onCrop: _handleCropPhoto,
                          onRotateCW: (item) => controller.rotatePhoto(item.id),
                          onRotateCCW: (item) => controller.rotatePhotoCounterClockwise(item.id),
                          onFlipHorizontal: (item) =>
                              controller.flipPhotoHorizontal(item.id),
                          onFlipVertical: (item) =>
                              controller.flipPhotoVertical(item.id),
                          onFilterTap: (item) => _showFilterSheet(context, item),
                          onDelete: (item) => controller.removePhoto(item.id),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 90),
                          itemCount: state.photos.length,
                          onReorderItem: (oldIndex, newIndex) =>
                              controller.reorderPhotos(oldIndex, newIndex),
                          itemBuilder: (context, index) {
                            final item = state.photos[index];
                            return DraggablePhotoCard(
                              key: ValueKey(item.id),
                              item: item,
                              index: index,
                              onCrop: () => _handleCropPhoto(item),
                              onRotateCW: () => controller.rotatePhoto(item.id),
                              onRotateCCW: () => controller.rotatePhotoCounterClockwise(item.id),
                              onFlipHorizontal: () =>
                                  controller.flipPhotoHorizontal(item.id),
                              onFlipVertical: () =>
                                  controller.flipPhotoVertical(item.id),
                              onFilterTap: () =>
                                  _showFilterSheet(context, item),
                              onDelete: () => controller.removePhoto(item.id),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: state.photos.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress Indicator during generation
                    if (state.isLoading) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            state.progressMessage ?? 'Generating PDF…',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            '${(state.progressPercent * 100).toInt()}%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: state.progressPercent > 0 ? state.progressPercent : null,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: state.isLoading
                              ? null
                              : () => controller.pickPhotosFromGallery(),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Add More'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(120, 52)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: state.isLoading ? null : _startPdfGeneration,
                            icon: state.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_rounded),
                            label: Text(state.isLoading ? 'Generating…' : 'Generate PDF'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
