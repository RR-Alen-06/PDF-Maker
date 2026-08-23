import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_maker/features/tools/pdf_manipulation/services/pdf_manipulation_service.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/services/pdf_generator_service.dart';
import 'package:pdf_maker/features/tools/pdf_compressor/services/pdf_compressor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Manipulation & Compressor Tests', () {
    late String samplePdfPath1;
    late String samplePdfPath2;

    setUpAll(() async {
      // Generate two real PDFs to test merging, splitting, and security
      final sample = img.Image(width: 100, height: 100);
      img.fill(sample, color: img.ColorRgb8(0, 100, 200));
      final bytes = Uint8List.fromList(img.encodeJpg(sample));

      final tempDir = Directory.systemTemp.createTempSync();
      final imgFile = File('${tempDir.path}/img.jpg');
      await imgFile.writeAsBytes(bytes);

      final photos1 = [
        PhotoItem(id: '1', path: imgFile.path, cachedBytes: bytes),
        PhotoItem(id: '2', path: imgFile.path, cachedBytes: bytes),
      ];
      final pdf1 = await PdfGeneratorService.generatePdf(
        photos: photos1,
        config: const PdfExportConfig(),
      );
      final file1 = File('${tempDir.path}/doc1.pdf');
      await file1.writeAsBytes(pdf1);
      samplePdfPath1 = file1.path;

      final photos2 = [
        PhotoItem(id: '3', path: imgFile.path, cachedBytes: bytes),
      ];
      final pdf2 = await PdfGeneratorService.generatePdf(
        photos: photos2,
        config: const PdfExportConfig(),
      );
      final file2 = File('${tempDir.path}/doc2.pdf');
      await file2.writeAsBytes(pdf2);
      samplePdfPath2 = file2.path;
    });

    test('Merges multiple PDF documents into a combined file', () async {
      final merged = await PdfManipulationService.mergePdfs([samplePdfPath1, samplePdfPath2]);
      expect(merged, isNotNull);
      expect(merged.isNotEmpty, true);
      expect(merged.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Splits and extracts specific page range', () async {
      final splitBytes = await PdfManipulationService.splitPdf(
        pdfPath: samplePdfPath1,
        pageNumbers: [1],
      );
      expect(splitBytes, isNotNull);
      expect(splitBytes.isNotEmpty, true);
    });

    test('Applies password security and encrypts PDF bytes', () async {
      final encrypted = await PdfManipulationService.applyPassword(
        pdfPath: samplePdfPath1,
        userPassword: 'SecretPassword123',
        ownerPassword: 'SecretPassword123',
      );
      expect(encrypted, isNotNull);
      expect(encrypted.isNotEmpty, true);
    });

    test('Compresses PDF streams and calculates savings', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final result = await PdfCompressorService.compressPdf(
        pdfPath: samplePdfPath1,
        imageQuality: 50,
        outputDirectory: tempDir.path,
      );
      expect(result.compressedBytes, isNotNull);
      expect(result.compressedSizeBytes > 0, true);
    });
  });
}
