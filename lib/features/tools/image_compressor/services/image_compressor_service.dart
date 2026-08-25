import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CompressedImageResult {
  final String originalPath;
  final String outputPath;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final Uint8List previewBytes;

  const CompressedImageResult({
    required this.originalPath,
    required this.outputPath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.previewBytes,
  });

  double get reductionPercentage => originalSizeBytes > 0
      ? ((originalSizeBytes - compressedSizeBytes) / originalSizeBytes) * 100
      : 0.0;
}

class ImageCompressorService {
  ImageCompressorService._();

  /// Estimates the compressed output size in bytes given quality (1-100) or target size in KB
  static int estimateCompressedSize({
    required int originalSizeBytes,
    required int quality,
    int? targetSizeKb,
  }) {
    if (targetSizeKb != null && targetSizeKb > 0) {
      final targetBytes = targetSizeKb * 1024;
      return targetBytes < originalSizeBytes ? targetBytes : originalSizeBytes;
    }
    final factor = (quality / 100.0).clamp(0.1, 1.0);
    return (originalSizeBytes * factor * 0.7).round().clamp(1024, originalSizeBytes);
  }

  /// Derives the appropriate quality level (1-100) needed to meet a target size in KB
  static int deriveQualityForTargetSize({
    required int originalSizeBytes,
    required int targetSizeKb,
  }) {
    final targetBytes = targetSizeKb * 1024;
    if (targetBytes >= originalSizeBytes) return 95;
    final ratio = targetBytes / originalSizeBytes;
    final quality = (ratio * 120).round().clamp(10, 95);
    return quality;
  }

  /// Compress single image with given quality percentage (1-100) or target size in KB.
  /// Saves to output directory with pattern `<original_name>_compressed.<ext>`.
  static Future<CompressedImageResult> compressImage({
    required String imagePath,
    required int quality,
    int? targetSizeKb,
    Directory? customOutputDir,
  }) async {
    final originalFile = File(imagePath);
    final originalBytes = await originalFile.readAsBytes();
    final originalSize = originalBytes.lengthInBytes;

    // When both Quality and Target Size are set, Target Size takes precedence
    int effectiveQuality = quality;
    if (targetSizeKb != null && targetSizeKb >= 10) {
      effectiveQuality = deriveQualityForTargetSize(
        originalSizeBytes: originalSize,
        targetSizeKb: targetSizeKb,
      );
    }

    final baseDir = customOutputDir ?? await getTemporaryDirectory();
    final fileNameWithExt = p.basename(imagePath);
    final ext = p.extension(fileNameWithExt);
    final nameWithoutExt = p.basenameWithoutExtension(fileNameWithExt);
    final targetPath = p.join(baseDir.path, '${nameWithoutExt}_compressed$ext');

    Uint8List? compressedBytes;
    try {
      final xFile = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: effectiveQuality,
      );
      if (xFile != null) {
        compressedBytes = await xFile.readAsBytes();
      }
    } catch (_) {
      // Fallback to pure-dart image package
      final decoded = img.decodeImage(originalBytes);
      if (decoded != null) {
        if (ext.toLowerCase() == '.png') {
          compressedBytes = Uint8List.fromList(img.encodePng(decoded, level: 6));
        } else {
          compressedBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: effectiveQuality));
        }
        final f = File(targetPath);
        await f.writeAsBytes(compressedBytes, flush: true);
      }
    }

    compressedBytes ??= originalBytes;

    return CompressedImageResult(
      originalPath: imagePath,
      outputPath: targetPath,
      originalSizeBytes: originalSize,
      compressedSizeBytes: compressedBytes.lengthInBytes,
      previewBytes: compressedBytes,
    );
  }

  /// Compress batch of images (1-50 images)
  static Future<List<CompressedImageResult>> compressBatch({
    required List<String> imagePaths,
    required int quality,
    int? targetSizeKb,
    Directory? customOutputDir,
  }) async {
    final results = <CompressedImageResult>[];
    for (final path in imagePaths) {
      final res = await compressImage(
        imagePath: path,
        quality: quality,
        targetSizeKb: targetSizeKb,
        customOutputDir: customOutputDir,
      );
      results.add(res);
    }
    return results;
  }
}
