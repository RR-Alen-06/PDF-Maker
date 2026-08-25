import 'dart:io';
import 'package:flutter/foundation.dart';

enum PhotoFilter {
  none('Original'),
  grayscale('Grayscale'),
  blackAndWhite('Document (B&W)'),
  enhanced('Enhanced Contrast');

  final String label;
  const PhotoFilter(this.label);
}

@immutable
class PhotoItem {
  final String id;
  final String path;
  final Uint8List? cachedBytes;
  final int rotationDegrees; // 0, 90, 180, 270
  final bool isFlippedHorizontally;
  final bool isFlippedVertically;
  final PhotoFilter filter;
  final int width;
  final int height;
  final int originalSizeBytes;
  final bool wasAutoDownscaled;

  const PhotoItem({
    required this.id,
    required this.path,
    this.cachedBytes,
    this.rotationDegrees = 0,
    this.isFlippedHorizontally = false,
    this.isFlippedVertically = false,
    this.filter = PhotoFilter.none,
    this.width = 0,
    this.height = 0,
    this.originalSizeBytes = 0,
    this.wasAutoDownscaled = false,
  });

  /// Approximate uncompressed RGBA decoded size in bytes (width * height * 4)
  int get decodedSizeBytes => width * height * 4;

  PhotoItem copyWith({
    String? id,
    String? path,
    Uint8List? cachedBytes,
    int? rotationDegrees,
    bool? isFlippedHorizontally,
    bool? isFlippedVertically,
    PhotoFilter? filter,
    int? width,
    int? height,
    int? originalSizeBytes,
    bool? wasAutoDownscaled,
    bool clearCachedBytes = false,
  }) {
    return PhotoItem(
      id: id ?? this.id,
      path: path ?? this.path,
      cachedBytes: clearCachedBytes ? null : (cachedBytes ?? this.cachedBytes),
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      isFlippedHorizontally: isFlippedHorizontally ?? this.isFlippedHorizontally,
      isFlippedVertically: isFlippedVertically ?? this.isFlippedVertically,
      filter: filter ?? this.filter,
      width: width ?? this.width,
      height: height ?? this.height,
      originalSizeBytes: originalSizeBytes ?? this.originalSizeBytes,
      wasAutoDownscaled: wasAutoDownscaled ?? this.wasAutoDownscaled,
    );
  }

  File get file => File(path);

  bool get isLandscape => rotationDegrees % 180 == 0
      ? width > height
      : height > width;
}
