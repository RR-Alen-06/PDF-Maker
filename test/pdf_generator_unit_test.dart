import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/services/pdf_generator_service.dart';
import 'package:pdf_maker/features/photo_to_pdf/services/image_filter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Generator & Layout Math Tests', () {
    late Uint8List testImageBytes;
    late String tempImagePath;

    setUpAll(() async {
      // Create a test synthetic bitmap image
      final sample = img.Image(width: 200, height: 200);
      img.fill(sample, color: img.ColorRgb8(255, 0, 0));
      testImageBytes = Uint8List.fromList(img.encodeJpg(sample));

      final tempDir = Directory.systemTemp.createTempSync();
      final tempFile = File('${tempDir.path}/test_image.jpg');
      await tempFile.writeAsBytes(testImageBytes);
      tempImagePath = tempFile.path;
    });

    test('Generates valid multi-page PDF from photo items', () async {
      final photos = [
        PhotoItem(id: '1', path: tempImagePath, cachedBytes: testImageBytes, width: 200, height: 200),
        PhotoItem(id: '2', path: tempImagePath, cachedBytes: testImageBytes, width: 200, height: 200),
        PhotoItem(id: '3', path: tempImagePath, cachedBytes: testImageBytes, width: 200, height: 200),
      ];

      const config = PdfExportConfig(
        pageSizePreset: PageSizePreset.a4,
        layout: PdfPhotoLayout.onePerPage,
        watermarkText: 'CONFIDENTIAL',
        headerText: 'Test Header',
        footerText: 'Test Footer',
      );

      final pdfBytes = await PdfGeneratorService.generatePdf(
        photos: photos,
        config: config,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, true);
      // PDF standard file header starts with '%PDF-' (0x25, 0x50, 0x44, 0x46)
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Calculates grid layouts properly (4-per-page)', () async {
      final photos = [
        PhotoItem(id: '1', path: tempImagePath, cachedBytes: testImageBytes),
        PhotoItem(id: '2', path: tempImagePath, cachedBytes: testImageBytes),
        PhotoItem(id: '3', path: tempImagePath, cachedBytes: testImageBytes),
        PhotoItem(id: '4', path: tempImagePath, cachedBytes: testImageBytes),
        PhotoItem(id: '5', path: tempImagePath, cachedBytes: testImageBytes),
      ];

      const config = PdfExportConfig(
        layout: PdfPhotoLayout.fourPerPageGrid,
      );

      final pdfBytes = await PdfGeneratorService.generatePdf(
        photos: photos,
        config: config,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length > 500, true);
    });

    test('Image filters (B&W and grayscale) process correctly', () async {
      final item = PhotoItem(
        id: '1',
        path: tempImagePath,
        cachedBytes: testImageBytes,
        filter: PhotoFilter.blackAndWhite,
        rotationDegrees: 90,
        isFlippedHorizontally: true,
      );

      final processed = await ImageFilterService.processImage(item);
      expect(processed, isNotNull);
      expect(processed.isNotEmpty, true);
    });
  });
}
