import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class PdfManipulationService {
  PdfManipulationService._();

  /// Merge multiple PDF files into one output file
  static Future<Uint8List> mergePdfs(List<String> pdfPaths) async {
    final sf.PdfDocument finalDoc = sf.PdfDocument();

    for (final path in pdfPaths) {
      final bytes = await File(path).readAsBytes();
      final loadedDoc = sf.PdfDocument(inputBytes: bytes);
      for (int i = 0; i < loadedDoc.pages.count; i++) {
        final section = finalDoc.sections!.add();
        section.pageSettings.size = loadedDoc.pages[i].size;
        final template = loadedDoc.pages[i].createTemplate();
        section.pages.add().graphics.drawPdfTemplate(
              template,
              const ui.Offset(0, 0),
            );
      }
      loadedDoc.dispose();
    }

    final List<int> mergedBytes = finalDoc.saveSync();
    finalDoc.dispose();
    return Uint8List.fromList(mergedBytes);
  }

  /// Split PDF: extracts a range of pages (1-indexed) into a new PDF
  static Future<Uint8List> splitPdf({
    required String pdfPath,
    required List<int> pageNumbers, // 1-indexed
  }) async {
    final bytes = await File(pdfPath).readAsBytes();
    final sourceDoc = sf.PdfDocument(inputBytes: bytes);
    final newDoc = sf.PdfDocument();

    for (final pageNum in pageNumbers) {
      if (pageNum >= 1 && pageNum <= sourceDoc.pages.count) {
        final zeroIndex = pageNum - 1;
        final section = newDoc.sections!.add();
        section.pageSettings.size = sourceDoc.pages[zeroIndex].size;
        final template = sourceDoc.pages[zeroIndex].createTemplate();
        section.pages.add().graphics.drawPdfTemplate(
              template,
              const ui.Offset(0, 0),
            );
      }
    }

    sourceDoc.dispose();
    final List<int> outputBytes = newDoc.saveSync();
    newDoc.dispose();
    return Uint8List.fromList(outputBytes);
  }

  /// Reorder, rotate, and delete pages in an existing PDF
  static Future<Uint8List> reorganizePdf({
    required String pdfPath,
    required List<int> pageOrder, // 1-indexed list of page numbers to keep in order
    required Map<int, int> pageRotations, // 1-indexed page number -> degrees (0, 90, 180, 270)
  }) async {
    final bytes = await File(pdfPath).readAsBytes();
    final sourceDoc = sf.PdfDocument(inputBytes: bytes);
    final newDoc = sf.PdfDocument();

    for (final pageNum in pageOrder) {
      if (pageNum >= 1 && pageNum <= sourceDoc.pages.count) {
        final zeroIndex = pageNum - 1;
        final section = newDoc.sections!.add();
        final rotation = pageRotations[pageNum] ?? 0;

        if (rotation == 90 || rotation == 270) {
          section.pageSettings.size = ui.Size(
            sourceDoc.pages[zeroIndex].size.height,
            sourceDoc.pages[zeroIndex].size.width,
          );
        } else {
          section.pageSettings.size = sourceDoc.pages[zeroIndex].size;
        }

        final template = sourceDoc.pages[zeroIndex].createTemplate();
        final newPage = section.pages.add();

        if (rotation != 0) {
          newPage.graphics.translateTransform(
            rotation == 90 || rotation == 180 ? newPage.size.width : 0,
            rotation == 180 || rotation == 270 ? newPage.size.height : 0,
          );
          newPage.graphics.rotateTransform(rotation.toDouble());
        }

        newPage.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
      }
    }

    sourceDoc.dispose();
    final List<int> resultBytes = newDoc.saveSync();
    newDoc.dispose();
    return Uint8List.fromList(resultBytes);
  }

  /// Protect PDF with User and Owner passwords
  static Future<Uint8List> applyPassword({
    required String pdfPath,
    required String userPassword,
    required String ownerPassword,
  }) async {
    final bytes = await File(pdfPath).readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    final security = doc.security;
    security.userPassword = userPassword;
    security.ownerPassword = ownerPassword;
    security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    security.permissions.addAll([
      sf.PdfPermissionsFlags.print,
      sf.PdfPermissionsFlags.copyContent,
    ]);

    final List<int> encrypted = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(encrypted);
  }

  /// Remove password from a protected PDF
  static Future<Uint8List> removePassword({
    required String pdfPath,
    required String password,
  }) async {
    final bytes = await File(pdfPath).readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes, password: password);
    final docDecrypted = sf.PdfDocument();
    for (int i = 0; i < doc.pages.count; i++) {
      final section = docDecrypted.sections!.add();
      section.pageSettings.size = doc.pages[i].size;
      final template = doc.pages[i].createTemplate();
      section.pages.add().graphics.drawPdfTemplate(
            template,
            const ui.Offset(0, 0),
          );
    }
    doc.dispose();
    final List<int> decrypted = docDecrypted.saveSync();
    docDecrypted.dispose();
    return Uint8List.fromList(decrypted);
  }
}
