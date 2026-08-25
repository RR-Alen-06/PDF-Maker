import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';
import 'package:pdf_maker/features/photo_to_pdf/services/pdf_generator_service.dart';

void main() {
  group('Requirement 2 & 3: Layout, Progress, and Undo/Redo Tests', () {
    late Uint8List testImageBytes;

    setUpAll(() {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      testImageBytes = Uint8List.fromList(img.encodeJpg(image));
    });

    test('PdfGeneratorService reports real-time page progress', () async {
      final photos = List.generate(
        5,
        (i) => PhotoItem(
          id: 'photo_$i',
          path: '/dummy_$i.jpg',
          cachedBytes: testImageBytes,
          width: 100,
          height: 100,
        ),
      );

      // 5 photos in 2-per-page mode => 3 pages
      const config = PdfExportConfig(layout: PdfPhotoLayout.twoPerPageSideBySide);
      final reportedPages = <int>[];
      final totalReported = <int>[];

      final pdfBytes = await PdfGeneratorService.generatePdf(
        photos: photos,
        config: config,
        onPageProgress: (current, total) {
          reportedPages.add(current);
          totalReported.add(total);
        },
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(reportedPages, equals([1, 2, 3]));
      expect(totalReported, equals([3, 3, 3]));
    });

    test('PhotoToPdfController manages Undo and Redo stack during reorder and layout changes', () {
      final controller = PhotoToPdfController();
      final p1 = PhotoItem(id: '1', path: '/1.jpg', cachedBytes: testImageBytes);
      final p2 = PhotoItem(id: '2', path: '/2.jpg', cachedBytes: testImageBytes);
      final p3 = PhotoItem(id: '3', path: '/3.jpg', cachedBytes: testImageBytes);

      controller.updateConfig(const PdfExportConfig());

      // Set initial photos
      controller.state = controller.state.copyWith(photos: [p1, p2, p3]);
      expect(controller.state.photos.length, equals(3));
      expect(controller.state.canUndo, isFalse);

      // Reorder item 0 to index 2
      controller.reorderPhotos(0, 2);
      expect(controller.state.photos.map((p) => p.id).toList(), equals(['2', '1', '3']));
      expect(controller.state.canUndo, isTrue);

      // Undo reorder
      controller.undo();
      expect(controller.state.photos.map((p) => p.id).toList(), equals(['1', '2', '3']));
      expect(controller.state.canRedo, isTrue);

      // Redo reorder
      controller.redo();
      expect(controller.state.photos.map((p) => p.id).toList(), equals(['2', '1', '3']));
    });

    test('Empty slots are calculated properly across all layout presets', () {
      for (final layout in PdfPhotoLayout.values) {
        expect(layout.photosPerPage, greaterThanOrEqualTo(1));
        expect(layout.photosPerPage, lessThanOrEqualTo(6));
      }

      // Check partial page arithmetic: 5 photos in 4-per-page grid -> Page 1 has 4 photos (0 empty), Page 2 has 1 photo (3 empty)
      const fourGrid = PdfPhotoLayout.fourPerPageGrid;
      const totalPhotos = 5;
      final totalPages = (totalPhotos / fourGrid.photosPerPage).ceil();
      expect(totalPages, equals(2));

      final page2Photos = totalPhotos - (1 * fourGrid.photosPerPage);
      final page2EmptySlots = fourGrid.photosPerPage - page2Photos;
      expect(page2Photos, equals(1));
      expect(page2EmptySlots, equals(3));
    });
  });
}
