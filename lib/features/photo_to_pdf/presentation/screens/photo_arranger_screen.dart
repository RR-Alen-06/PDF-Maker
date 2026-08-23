import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/widgets/draggable_photo_card.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/widgets/layout_selector.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/screens/page_setup_modal.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/screens/pdf_preview_screen.dart';

class PhotoArrangerScreen extends ConsumerWidget {
  const PhotoArrangerScreen({super.key});

  void _showFilterSheet(BuildContext context, WidgetRef ref, PhotoItem item) {
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

  void _showPageSetupModal(BuildContext context, WidgetRef ref) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(photoToPdfProvider);
    final controller = ref.read(photoToPdfProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrange & Layout'),
        actions: [
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
            onPressed: () => _showPageSetupModal(context, ref),
          ),
        ],
      ),
      body: state.photos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No photos selected yet', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => controller.pickPhotosFromGallery(),
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('Pick Photos'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Layout Selector Toolbar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: LayoutSelector(
                    selectedLayout: state.config.layout,
                    onLayoutSelected: (layout) => controller.updateLayout(layout),
                  ),
                ),

                // Info banner (Page count summary)
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
                      Text(
                        '${state.photos.length} photos • ${(state.photos.length / state.config.layout.photosPerPage).ceil()} PDF page(s) (${state.config.pageSizePreset.label})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // Drag & Drop Reorderable List
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: state.photos.length,
                    onReorderItem: (oldIndex, newIndex) =>
                        controller.reorderPhotos(oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final item = state.photos[index];
                      return DraggablePhotoCard(
                        key: ValueKey(item.id),
                        item: item,
                        index: index,
                        onRotate: () => controller.rotatePhoto(item.id),
                        onFlipHorizontal: () =>
                            controller.flipPhotoHorizontal(item.id),
                        onFilterTap: () =>
                            _showFilterSheet(context, ref, item),
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
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => controller.pickPhotosFromGallery(),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add More'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(120, 52)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state.isLoading
                            ? null
                            : () async {
                                final bytes = await controller.generatePdf();
                                if (bytes != null && context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PdfPreviewScreen(
                                        suggestedFileName:
                                            FileUtils.generateDefaultFileName(
                                          prefix: 'Photos_Document',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
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
                        label: Text(state.isLoading ? 'Generating...' : 'Preview PDF'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
