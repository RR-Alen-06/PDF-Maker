import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';

void main() {
  group('Requirement 1: Photo Selection & Validation Unit Tests', () {
    test('Supported image extensions set contains required formats (JPG, PNG, WEBP, HEIC)', () {
      expect(kSupportedImageExtensions.contains('.jpg'), isTrue);
      expect(kSupportedImageExtensions.contains('.jpeg'), isTrue);
      expect(kSupportedImageExtensions.contains('.png'), isTrue);
      expect(kSupportedImageExtensions.contains('.webp'), isTrue);
      expect(kSupportedImageExtensions.contains('.heic'), isTrue);
      expect(kSupportedImageExtensions.contains('.heif'), isTrue);
      expect(kSupportedImageExtensions.contains('.exe'), isFalse);
      expect(kSupportedImageExtensions.contains('.pdf'), isFalse);
      expect(kSupportedImageExtensions.contains('.txt'), isFalse);
    });

    test('PhotoItem calculates uncompressed decoded size correctly', () {
      const item = PhotoItem(
        id: 'test_1',
        path: '/tmp/sample.jpg',
        width: 4000,
        height: 3000,
      );

      // 4000 * 3000 * 4 = 48,000,000 bytes (~48 MB)
      expect(item.decodedSizeBytes, equals(48000000));
      expect(item.decodedSizeBytes <= kMaxDecodedSizeBytes, isTrue);

      const largeItem = PhotoItem(
        id: 'test_large',
        path: '/tmp/huge.jpg',
        width: 6000,
        height: 4000,
      );
      // 6000 * 4000 * 4 = 96,000,000 bytes (> 50 MB)
      expect(largeItem.decodedSizeBytes, equals(96000000));
      expect(largeItem.decodedSizeBytes > kMaxDecodedSizeBytes, isTrue);
    });

    test('PhotoToPdfState validates minimum 2 photos', () {
      const emptyState = PhotoToPdfState(photos: []);
      expect(emptyState.hasSufficientPhotos, isFalse);

      const singleState = PhotoToPdfState(photos: [
        PhotoItem(id: '1', path: '/test1.jpg'),
      ]);
      expect(singleState.hasSufficientPhotos, isFalse);

      const validState = PhotoToPdfState(photos: [
        PhotoItem(id: '1', path: '/test1.jpg'),
        PhotoItem(id: '2', path: '/test2.jpg'),
      ]);
      expect(validState.hasSufficientPhotos, isTrue);
    });
  });

  group('Requirement 5: File Naming & Sanitization Unit Tests', () {
    test('sanitizeFileName strips invalid filesystem characters', () {
      expect(FileUtils.sanitizeFileName('Invoice: 2026/08/25*?'), equals('Invoice 20260825'));
      expect(FileUtils.sanitizeFileName('Scan<Document>|"Test"'), equals('ScanDocumentTest'));
      expect(FileUtils.sanitizeFileName('Regular_Name_123'), equals('Regular_Name_123'));
    });

    test('generateNextDefaultFileName produces Scan_YYYY-MM-DD_001 format and increments', () async {
      final tempDir = await Directory.systemTemp.createTemp('pdf_name_test_');

      final date = DateTime(2026, 8, 25);
      final first = await FileUtils.generateNextDefaultFileName(date: date, targetDir: tempDir);
      expect(first, equals('Scan_2026-08-25_001.pdf'));

      // Create dummy file for 001
      final f1 = File('${tempDir.path}/$first');
      await f1.writeAsString('test');

      final second = await FileUtils.generateNextDefaultFileName(date: date, targetDir: tempDir);
      expect(second, equals('Scan_2026-08-25_002.pdf'));

      // Create dummy file for 002
      final f2 = File('${tempDir.path}/$second');
      await f2.writeAsString('test');

      final third = await FileUtils.generateNextDefaultFileName(date: date, targetDir: tempDir);
      expect(third, equals('Scan_2026-08-25_003.pdf'));

      await tempDir.delete(recursive: true);
    });
  });
}
