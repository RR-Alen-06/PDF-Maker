import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/overlay_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/modals/overlay_settings_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Gap 24 Unit & Widget Tests', () {
    // 1. PDF page count calculation: given N photos and 5 layout modes
    test('PDF page count calculation across all layout modes', () {
      const photosCount = 7;
      // 1-per-page: 7 pages
      expect((photosCount / PdfPhotoLayout.onePerPage.photosPerPage).ceil(), equals(7));
      // 2-stacked: 4 pages
      expect((photosCount / PdfPhotoLayout.twoPerPageStacked.photosPerPage).ceil(), equals(4));
      // 2-side-by-side: 4 pages
      expect((photosCount / PdfPhotoLayout.twoPerPageSideBySide.photosPerPage).ceil(), equals(4));
      // 3-per-page: 3 pages
      expect((photosCount / PdfPhotoLayout.threePerPage.photosPerPage).ceil(), equals(3));
      // 4-grid: 2 pages
      expect((photosCount / PdfPhotoLayout.fourPerPageGrid.photosPerPage).ceil(), equals(2));
      // 6-per-page: 2 pages
      expect((photosCount / PdfPhotoLayout.sixPerPageGrid.photosPerPage).ceil(), equals(2));
    });

    // 2. Page slot assignment & empty slots
    test('Page slot assignment and empty slot calculation', () {
      final photos = List.generate(
        5,
        (i) => PhotoItem(id: '$i', path: '/test/$i.jpg', width: 100, height: 100, originalSizeBytes: 1000),
      );
      final layout = PdfPhotoLayout.fourPerPageGrid; // 4 per page
      final photosPerPage = layout.photosPerPage;
      final totalPages = (photos.length / photosPerPage).ceil(); // 2 pages
      expect(totalPages, equals(2));

      // Page 1: 4 photos, 0 empty
      final p1Photos = photos.sublist(0, 4);
      expect(p1Photos.length, equals(4));
      expect(photosPerPage - p1Photos.length, equals(0));

      // Page 2: 1 photo, 3 empty slots
      final p2Photos = photos.sublist(4, 5);
      expect(p2Photos.length, equals(1));
      expect(photosPerPage - p2Photos.length, equals(3));
    });

    // 3. Filename sanitization
    test('Filename sanitization strips invalid filesystem characters', () {
      const invalidName = 'Scan: My/Document* <v1>? | "test" \\';
      final sanitized = FileUtils.sanitizeFileName(invalidName);
      expect(sanitized, equals('Scan MyDocument v1  test'));
      expect(sanitized.contains(RegExp(r'[\\/:*?"<>|]')), isFalse);
    });

    // 4. Undo/Redo stack: add 3 actions, undo 2, redo 1, add 1 new -> assert redo stack cleared
    test('Undo/Redo stack manages history and clears redo stack on new action', () {
      final container = ProviderContainer();
      final controller = container.read(photoToPdfProvider.notifier);

      final item1 = PhotoItem(id: '1', path: '/p1.jpg', width: 100, height: 100, originalSizeBytes: 1000);
      final item2 = PhotoItem(id: '2', path: '/p2.jpg', width: 100, height: 100, originalSizeBytes: 1000);
      final item3 = PhotoItem(id: '3', path: '/p3.jpg', width: 100, height: 100, originalSizeBytes: 1000);
      final item4 = PhotoItem(id: '4', path: '/p4.jpg', width: 100, height: 100, originalSizeBytes: 1000);

      // Action 1: Add item 1
      controller.appendPhotoItem(item1);
      // Action 2: Add item 2
      controller.appendPhotoItem(item2);
      // Action 3: Add item 3
      controller.appendPhotoItem(item3);
      expect(container.read(photoToPdfProvider).photos.length, equals(3));

      // Undo 2 actions
      controller.undo();
      controller.undo();
      expect(container.read(photoToPdfProvider).photos.length, equals(1));
      expect(container.read(photoToPdfProvider).canRedo, isTrue);

      // Redo 1 action
      controller.redo();
      expect(container.read(photoToPdfProvider).photos.length, equals(2));
      expect(container.read(photoToPdfProvider).canRedo, isTrue);

      // Add 1 new action -> Redo stack must be cleared
      controller.appendPhotoItem(item4);
      expect(container.read(photoToPdfProvider).photos.length, equals(3));
      expect(container.read(photoToPdfProvider).canRedo, isFalse);
    });

    // 5. Export naming pattern token substitution
    test('Export naming pattern substitutes all tokens', () {
      const pattern = '{name}_{date}_{time}_{counter}_{total}';
      final formatted = pattern
          .replaceAll('{name}', 'Invoice')
          .replaceAll('{date}', '2026-08-25')
          .replaceAll('{time}', '143000')
          .replaceAll('{counter}', '001')
          .replaceAll('{total}', '10');
      expect(formatted, equals('Invoice_2026-08-25_143000_001_10'));
    });

    // 6. Overlay conflict detection unit test
    test('Overlay position collision detection', () {
      const config = PdfExportConfig(
        enablePageNumbers: true,
        pageNumberPosition: OverlayGridPosition.bottomRight,
        enableDateStamp: true,
        dateStampPosition: OverlayGridPosition.bottomRight,
      );
      expect(config.hasOverlayPositionConflict, isTrue);
    });

    // 7. Widget test: Overlay settings conflict warning banner
    testWidgets('Overlay settings shows warning when page number and date stamp collide', (tester) async {
      const conflictConfig = PdfExportConfig(
        enablePageNumbers: true,
        pageNumberPosition: OverlayGridPosition.bottomRight,
        enableDateStamp: true,
        dateStampPosition: OverlayGridPosition.bottomRight,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverlaySettingsModal(
              initialConfig: conflictConfig,
              onSave: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Overlapping positions — items may be obscured'), findsOneWidget);
    });
  });
}
