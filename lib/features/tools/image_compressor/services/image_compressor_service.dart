import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Compress single image with given quality percentage (1-100) or target size
  static Future<CompressedImageResult> compressImage({
    required String imagePath,
    required int quality,
    int? maxTargetSizeBytes,
  }) async {
    final originalFile = File(imagePath);
    final originalBytes = await originalFile.readAsBytes();
    final originalSize = originalBytes.lengthInBytes;

    final tempDir = await getTemporaryDirectory();
    final fileName = originalPathToName(imagePath);
    final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_$fileName';

    // Compress with flutter_image_compress if supported, or fallback to pure-dart image package
    Uint8List? compressedBytes;
    try {
      final xFile = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: quality,
      );
      if (xFile != null) {
        compressedBytes = await xFile.readAsBytes();
      }
    } catch (_) {
      // Fallback to pure-dart image package
      final decoded = img.decodeImage(originalBytes);
      if (decoded != null) {
        compressedBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
        final f = File(targetPath);
        await f.writeAsBytes(compressedBytes);
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

  /// Compress batch of images
  static Future<List<CompressedImageResult>> compressBatch({
    required List<String> imagePaths,
    required int quality,
  }) async {
    final results = <CompressedImageResult>[];
    for (final path in imagePaths) {
      final res = await compressImage(imagePath: path, quality: quality);
      results.add(res);
    }
    return results;
  }

  static String originalPathToName(String path) {
    return path.split(Platform.pathSeparator).last;
  }
}
