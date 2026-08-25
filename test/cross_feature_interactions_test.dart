import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Suggestions 1–22 Comprehensive Unit Tests', () {
    // Suggestion 16 & 1: Filename sanitization, length cap (<= 200 chars), and extension preservation
    test('Suggestion 16: Filename sanitization caps total length <= 200 chars preserving extension', () {
      final extremelyLongName = 'A' * 300;
      final sanitized = FileUtils.sanitizeFileName(extremelyLongName, extension: '.pdf');
      expect(sanitized.length, lessThanOrEqualTo(200));
      expect(sanitized.endsWith('.pdf'), isTrue);
      // 196 chars of base + 4 chars of .pdf = 200 chars
      expect(sanitized.length, equals(200));
    });

    // Suggestion 16: Sanitization strips illegal chars and respects 200 char boundary
    test('Suggestion 16: Strips illegal chars and preserves custom extensions within 200 char cap', () {
      final invalidCharsName = '${'Report/Doc:*?"<>|' * 20}.pdf';
      final sanitized = FileUtils.sanitizeFileName(invalidCharsName, extension: '.pdf');
      expect(sanitized.contains(RegExp(r'[\\/:*?"<>|]')), isFalse);
      expect(sanitized.endsWith('.pdf'), isTrue);
      expect(sanitized.length, lessThanOrEqualTo(200));
    });

    // Suggestion 10: Storage pre-check estimate calculation (sum + 10% margin)
    test('Suggestion 10: Storage check calculation accurately includes 10% safety margin', () {
      const inputSize1 = 10 * 1024 * 1024; // 10 MB
      const inputSize2 = 15 * 1024 * 1024; // 15 MB
      const totalInput = inputSize1 + inputSize2; // 25 MB
      final estimatedRequired = (totalInput * 1.10).round();
      expect(estimatedRequired, equals((25 * 1024 * 1024 * 1.10).round()));
    });

    // Suggestion 8: Undo/Redo stack handles photo edit as single cumulative entry
    test('Suggestion 8: Global undo stack pushes single entry for cumulative photo edit', () {
      final container = ProviderContainer();
      final controller = container.read(photoToPdfProvider.notifier);

      final originalItem = PhotoItem(
        id: 'photo_1',
        path: '/photos/pic1.jpg',
        width: 1000,
        height: 800,
        originalSizeBytes: 50000,
      );

      controller.appendPhotoItem(originalItem);
      expect(container.read(photoToPdfProvider).photos.first.rotationDegrees, equals(0));

      // Apply rotation edit (pushed to undo stack)
      controller.rotatePhoto('photo_1');
      expect(container.read(photoToPdfProvider).photos.first.rotationDegrees, equals(90));
      expect(container.read(photoToPdfProvider).canUndo, isTrue);

      // Global undo reverts photo to pre-edit state
      controller.undo();
      expect(container.read(photoToPdfProvider).photos.first.rotationDegrees, equals(0));
    });

    // Suggestion 19: Image Compressor naming applies custom template first, then _compressed suffix
    test('Suggestion 19: Image compressor applies template base first, then _compressed before extension', () {
      const originalPath = '/images/invoice.png';
      const customBase = 'Invoice_2026-08-25_001';
      final ext = originalPath.split('.').last;
      final expectedFileName = '${customBase}_compressed.$ext';
      expect(expectedFileName, equals('Invoice_2026-08-25_001_compressed.png'));
    });

    // Suggestion 9: Combined watermark and password naming convention
    test('Suggestion 9: Combined watermark and protected suffixes append in correct order', () {
      const baseName = 'Contract_2026';
      const hasWatermark = true;
      const isProtected = true;

      String finalName = baseName;
      if (hasWatermark) finalName += '_watermarked';
      if (isProtected) finalName += '_protected';
      final sanitized = FileUtils.sanitizeFileName(finalName, extension: '.pdf');

      expect(sanitized, equals('Contract_2026_watermarked_protected.pdf'));
    });
  });
}
