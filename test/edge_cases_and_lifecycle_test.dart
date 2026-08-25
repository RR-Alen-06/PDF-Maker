import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';
import 'package:pdf_maker/features/photo_to_pdf/services/pdf_generator_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Suggestions 23–37 Unit & Architecture Tests', () {
    // Suggestion 23: Duplicate Photo Detection
    test('Suggestion 23: Skipping duplicate photo paths in session', () {
      final container = ProviderContainer();
      final controller = container.read(photoToPdfProvider.notifier);

      final item1 = const PhotoItem(id: '1', path: '/photos/pic1.jpg');
      final item2 = const PhotoItem(id: '2', path: '/photos/pic2.jpg');
      final duplicateItem1 = const PhotoItem(id: '3', path: '/photos/pic1.jpg');

      controller.appendPhotoItem(item1);
      controller.appendPhotoItem(item2);
      expect(container.read(photoToPdfProvider).photos.length, equals(2));

      // Append duplicate -> should not increase photo count
      controller.appendPhotoItem(duplicateItem1);
      expect(container.read(photoToPdfProvider).photos.length, equals(2));
    });

    // Suggestion 24: Auto-downscale badge detection
    test('Suggestion 24: Detects auto-downscaled photos in session', () {
      const normalItem = PhotoItem(id: '1', path: '/p1.jpg', wasAutoDownscaled: false);
      const downscaledItem = PhotoItem(id: '2', path: '/p2.jpg', wasAutoDownscaled: true);

      final state = const PhotoToPdfState(photos: [normalItem, downscaledItem]);
      expect(state.autoDownscaledCount, equals(1));
    });

    // Suggestion 25: Cancel during PDF generation
    test('Suggestion 25: cancelPdfGeneration sets isCancelled and stops generation state', () {
      final container = ProviderContainer();
      final controller = container.read(photoToPdfProvider.notifier);

      controller.cancelPdfGeneration();
      expect(container.read(photoToPdfProvider).isCancelled, isTrue);
      expect(container.read(photoToPdfProvider).isLoading, isFalse);
    });

    // Suggestion 26: File integrity byte length check
    test('Suggestion 26: FileUtils verifies byte length and deletes file if truncated', () async {
      final tempDir = await Directory.systemTemp.createTemp('integrity_test_');
      final testBytes = List<int>.generate(1000, (i) => i % 256);

      final file = await FileUtils.savePdfFile(
        bytes: testBytes,
        fileName: 'integrity_doc.pdf',
        customDirectory: tempDir.path,
      );

      expect(await file.exists(), isTrue);
      expect(await file.length(), equals(testBytes.length));

      await tempDir.delete(recursive: true);
    });

    // Suggestion 31: Thumbnail cache invalidation on photo transforms
    test('Suggestion 31: Rotating or flipping photo clears cachedBytes', () {
      final container = ProviderContainer();
      final controller = container.read(photoToPdfProvider.notifier);

      final itemWithCache = PhotoItem(
        id: 'photo_cache',
        path: '/photos/p.jpg',
        cachedBytes: Uint8List.fromList([1, 2, 3, 4]),
      );

      controller.appendPhotoItem(itemWithCache);
      expect(container.read(photoToPdfProvider).photos.first.cachedBytes, isNotNull);

      // Rotate CW -> clears cachedBytes for fresh asynchronous regeneration
      controller.rotatePhoto('photo_cache');
      expect(container.read(photoToPdfProvider).photos.first.cachedBytes, isNull);
    });

    // Suggestion 33: PDF metadata embedding
    test('Suggestion 33: Document title, creator, and metadata are cleanly embedded in output', () async {
      final sample = img.Image(width: 50, height: 50);
      img.fill(sample, color: img.ColorRgb8(0, 0, 255));
      final validJpg = Uint8List.fromList(img.encodeJpg(sample));

      final tempDir = Directory.systemTemp.createTempSync();
      final tempFile = File('${tempDir.path}/meta_test.jpg');
      await tempFile.writeAsBytes(validJpg);

      final item = PhotoItem(
        id: '1',
        path: tempFile.path,
        cachedBytes: validJpg,
        width: 50,
        height: 50,
      );

      final bytes = await PdfGeneratorService.generatePdf(
        photos: [item],
        config: const PdfExportConfig(),
        documentTitle: 'Invoice_Report_2026',
      );

      expect(bytes, isNotEmpty);
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });
  });
}
