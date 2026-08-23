import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../domain/models/photo_item.dart';

class ImageFilterService {
  ImageFilterService._();

  /// Process raw image file bytes applying rotation, flip, and document filters
  static Future<Uint8List> processImage(PhotoItem item) async {
    Uint8List bytes = item.cachedBytes ?? await File(item.path).readAsBytes();
    
    // If no edits are applied, return original bytes directly
    if (item.rotationDegrees == 0 &&
        !item.isFlippedHorizontally &&
        !item.isFlippedVertically &&
        item.filter == PhotoFilter.none) {
      return bytes;
    }

    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    // 1. Rotation
    if (item.rotationDegrees != 0) {
      decoded = img.copyRotate(decoded, angle: item.rotationDegrees);
    }

    // 2. Flip
    if (item.isFlippedHorizontally) {
      decoded = img.copyFlip(decoded, direction: img.FlipDirection.horizontal);
    }
    if (item.isFlippedVertically) {
      decoded = img.copyFlip(decoded, direction: img.FlipDirection.vertical);
    }

    // 3. Document Filters
    switch (item.filter) {
      case PhotoFilter.grayscale:
        decoded = img.grayscale(decoded);
        break;
      case PhotoFilter.blackAndWhite:
        // High contrast document thresholding (adaptive binarization)
        decoded = img.grayscale(decoded);
        decoded = img.contrast(decoded, contrast: 150);
        // Apply thresholding for crisp text
        for (final pixel in decoded) {
          final l = pixel.luminanceNormalized;
          final val = l > 0.55 ? 255 : 0;
          pixel.r = val;
          pixel.g = val;
          pixel.b = val;
        }
        break;
      case PhotoFilter.enhanced:
        // Enhance contrast and sharpen for poor lighting scans
        decoded = img.adjustColor(
          decoded,
          contrast: 1.25,
          brightness: 1.05,
          saturation: 1.1,
        );
        break;
      case PhotoFilter.none:
        break;
    }

    return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
  }
}
