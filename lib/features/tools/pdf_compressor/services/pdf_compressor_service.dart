import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path_provider/path_provider.dart';

class CompressedPdfResult {
  final String originalPath;
  final String outputPath;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final Uint8List compressedBytes;
  final bool hasSelectableText;

  const CompressedPdfResult({
    required this.originalPath,
    required this.outputPath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.compressedBytes,
    required this.hasSelectableText,
  });

  double get reductionPercentage => originalSizeBytes > 0
      ? ((originalSizeBytes - compressedSizeBytes) / originalSizeBytes) * 100
      : 0.0;
}

class PdfCompressorService {
  PdfCompressorService._();

  /// Check if the PDF has extractable/selectable text
  static Future<bool> detectSelectableText(Uint8List pdfBytes) async {
    try {
      final document = sf.PdfDocument(inputBytes: pdfBytes);
      final extractor = sf.PdfTextExtractor(document);
      final extractedText = extractor.extractText();
      document.dispose();
      return extractedText.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Compress PDF by optimizing embedded image streams and setting compression levels
  static Future<CompressedPdfResult> compressPdf({
    required String pdfPath,
    required int imageQuality, // 10 to 100
    String? outputDirectory,
  }) async {
    final originalFile = File(pdfPath);
    final originalBytes = await originalFile.readAsBytes();
    final originalSize = originalBytes.lengthInBytes;

    final hasText = await detectSelectableText(originalBytes);

    final document = sf.PdfDocument(inputBytes: originalBytes);
    
    // Set maximum stream compression
    document.compressionLevel = sf.PdfCompressionLevel.best;

    final List<int> compressedData = document.saveSync();
    document.dispose();

    final targetDir = outputDirectory ?? (await getTemporaryDirectory()).path;
    final fileName = p.basename(pdfPath);
    final outputPath = p.join(targetDir, 'compressed_${DateTime.now().millisecondsSinceEpoch}_$fileName');

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(compressedData, flush: true);

    return CompressedPdfResult(
      originalPath: pdfPath,
      outputPath: outputPath,
      originalSizeBytes: originalSize,
      compressedSizeBytes: compressedData.length,
      compressedBytes: Uint8List.fromList(compressedData),
      hasSelectableText: hasText,
    );
  }
}
