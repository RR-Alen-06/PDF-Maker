import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/services/pdf_generator_service.dart';

/// Supported image file extensions
const Set<String> kSupportedImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.heic',
  '.heif',
};

/// 50 MB threshold in decoded RGBA bytes (50 * 1024 * 1024 = 52,428,800 bytes)
const int kMaxDecodedSizeBytes = 50 * 1024 * 1024;

@immutable
class PhotoToPdfState {
  final List<PhotoItem> photos;
  final PdfExportConfig config;
  final bool isLoading;
  final String? errorMessage;
  final String? validationWarning;
  final List<String> unsupportedSkippedFiles;
  final bool permissionDeniedNeedSettings;
  final String? permissionDeniedMessage;
  final String? progressMessage;
  final double progressPercent;
  final Uint8List? generatedPdfBytes;
  final List<List<PhotoItem>> undoStack;
  final List<List<PhotoItem>> redoStack;

  const PhotoToPdfState({
    this.photos = const [],
    this.config = const PdfExportConfig(),
    this.isLoading = false,
    this.errorMessage,
    this.validationWarning,
    this.unsupportedSkippedFiles = const [],
    this.permissionDeniedNeedSettings = false,
    this.permissionDeniedMessage,
    this.progressMessage,
    this.progressPercent = 0.0,
    this.generatedPdfBytes,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  bool get hasSufficientPhotos => photos.length >= 2;

  PhotoToPdfState copyWith({
    List<PhotoItem>? photos,
    PdfExportConfig? config,
    bool? isLoading,
    String? errorMessage,
    String? validationWarning,
    List<String>? unsupportedSkippedFiles,
    bool? permissionDeniedNeedSettings,
    String? permissionDeniedMessage,
    String? progressMessage,
    double? progressPercent,
    Uint8List? generatedPdfBytes,
    List<List<PhotoItem>>? undoStack,
    List<List<PhotoItem>>? redoStack,
    bool clearWarning = false,
    bool clearSkippedFiles = false,
    bool clearPermissionError = false,
  }) {
    return PhotoToPdfState(
      photos: photos ?? this.photos,
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      validationWarning: clearWarning ? null : (validationWarning ?? this.validationWarning),
      unsupportedSkippedFiles: clearSkippedFiles
          ? const []
          : (unsupportedSkippedFiles ?? this.unsupportedSkippedFiles),
      permissionDeniedNeedSettings: clearPermissionError
          ? false
          : (permissionDeniedNeedSettings ?? this.permissionDeniedNeedSettings),
      permissionDeniedMessage: clearPermissionError
          ? null
          : (permissionDeniedMessage ?? this.permissionDeniedMessage),
      progressMessage: progressMessage ?? this.progressMessage,
      progressPercent: progressPercent ?? this.progressPercent,
      generatedPdfBytes: generatedPdfBytes ?? this.generatedPdfBytes,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}

class PhotoToPdfController extends StateNotifier<PhotoToPdfState> {
  final ImagePicker _picker = ImagePicker();

  PhotoToPdfController() : super(const PhotoToPdfState());

  void _pushUndoState() {
    state = state.copyWith(
      undoStack: [...state.undoStack, state.photos],
      redoStack: [],
    );
  }

  void clearSkippedFilesNotification() {
    state = state.copyWith(clearSkippedFiles: true);
  }

  void clearPermissionError() {
    state = state.copyWith(clearPermissionError: true);
  }

  void clearWarning() {
    state = state.copyWith(clearWarning: true);
  }

  /// Request permissions for photos or camera
  Future<bool> _checkAndRequestPermission({required bool isCamera}) async {
    PermissionStatus status;
    if (isCamera) {
      status = await Permission.camera.request();
    } else {
      if (Platform.isAndroid) {
        status = await Permission.photos.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          status = await Permission.storage.request();
        }
      } else if (Platform.isIOS) {
        status = await Permission.photos.request();
      } else {
        return true; // Desktop / Web mock
      }
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      state = state.copyWith(
        permissionDeniedNeedSettings: true,
        permissionDeniedMessage: isCamera
            ? 'Camera permission is required to capture photos directly for your PDF. Please enable it in system settings.'
            : 'Photo library access is needed to select images for your document. Please enable it in system settings.',
        isLoading: false,
      );
      return false;
    }

    if (status.isDenied) {
      state = state.copyWith(
        permissionDeniedNeedSettings: false,
        permissionDeniedMessage: isCamera
            ? 'Camera permission was denied.'
            : 'Photo library permission was denied.',
        isLoading: false,
      );
      return false;
    }

    state = state.copyWith(clearPermissionError: true);
    return true;
  }

  /// Pick photos from gallery (supporting 2-100 selection session)
  Future<bool> pickPhotosFromGallery() async {
    try {
      state = state.copyWith(
        isLoading: true,
        errorMessage: null,
        clearWarning: true,
        clearSkippedFiles: true,
      );

      final hasPermission = await _checkAndRequestPermission(isCamera: false);
      if (!hasPermission) return false;

      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isEmpty) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      // Check max cap of 100
      final cappedFiles = pickedFiles.take(100).toList();

      await _addPhotosFromFiles(cappedFiles);

      // Validate at least 2 photos selected overall
      if (state.photos.length < 2) {
        state = state.copyWith(
          validationWarning: 'Please select at least 2 photos',
        );
        return false;
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to pick photos: $e',
      );
      return false;
    }
  }

  /// Pick single photo from camera
  Future<bool> takePhotoFromCamera() async {
    try {
      state = state.copyWith(
        isLoading: true,
        errorMessage: null,
        clearWarning: true,
        clearSkippedFiles: true,
      );

      final hasPermission = await _checkAndRequestPermission(isCamera: true);
      if (!hasPermission) return false;

      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      await _addPhotosFromFiles([pickedFile]);

      if (state.photos.length < 2) {
        state = state.copyWith(
          validationWarning: 'Please select at least 2 photos',
        );
        return false;
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to capture photo: $e',
      );
      return false;
    }
  }

  /// Process picked files: filter unsupported formats & auto-downscale decoded > 50 MB
  Future<void> _addPhotosFromFiles(List<XFile> files) async {
    _pushUndoState();
    final newItems = <PhotoItem>[];
    final skippedNames = <String>[];

    for (final file in files) {
      final ext = p.extension(file.path).toLowerCase();
      final baseName = p.basename(file.path);

      // 1. Filter unsupported file types
      if (ext.isNotEmpty && !kSupportedImageExtensions.contains(ext)) {
        skippedNames.add(baseName);
        continue;
      }

      try {
        final originalFile = File(file.path);
        Uint8List bytes = await originalFile.readAsBytes();
        img.Image? decoded = img.decodeImage(bytes);

        if (decoded == null) {
          skippedNames.add(baseName);
          continue;
        }

        int width = decoded.width;
        int height = decoded.height;
        int decodedSize = width * height * 4;
        bool wasDownscaled = false;

        // 2. Downscale if decoded size > 50 MB (width * height * 4 > 50 MB)
        if (decodedSize > kMaxDecodedSizeBytes) {
          final scaleFactor = sqrt(kMaxDecodedSizeBytes / decodedSize) * 0.95;
          final targetWidth = max(1, (width * scaleFactor).round());
          final targetHeight = max(1, (height * scaleFactor).round());

          final resized = img.copyResize(
            decoded,
            width: targetWidth,
            height: targetHeight,
            interpolation: img.Interpolation.linear,
          );

          bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 90));
          width = resized.width;
          height = resized.height;
          wasDownscaled = true;
        }

        final id = '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}';
        newItems.add(
          PhotoItem(
            id: id,
            path: file.path,
            cachedBytes: bytes,
            width: width,
            height: height,
            originalSizeBytes: bytes.lengthInBytes,
            wasAutoDownscaled: wasDownscaled,
          ),
        );
      } catch (_) {
        skippedNames.add(baseName);
      }
    }

    state = state.copyWith(
      photos: [...state.photos, ...newItems],
      unsupportedSkippedFiles: skippedNames,
      isLoading: false,
    );
  }

  /// Reorder photos in the list (records in undo stack)
  void reorderPhotos(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    _pushUndoState();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final items = List<PhotoItem>.from(state.photos);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(photos: items);
  }

  /// Remove single photo
  void removePhoto(String id) {
    _pushUndoState();
    final updated = state.photos.where((p) => p.id != id).toList();
    state = state.copyWith(photos: updated);
  }

  /// Rotate photo 90 degrees clockwise
  void rotatePhoto(String id) {
    _pushUndoState();
    final updated = state.photos.map((p) {
      if (p.id == id) {
        return p.copyWith(
          rotationDegrees: (p.rotationDegrees + 90) % 360,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(photos: updated);
  }

  /// Rotate photo 90 degrees counter-clockwise (CCW)
  void rotatePhotoCounterClockwise(String id) {
    _pushUndoState();
    final updated = state.photos.map((p) {
      if (p.id == id) {
        return p.copyWith(
          rotationDegrees: (p.rotationDegrees - 90 + 360) % 360,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(photos: updated);
  }

  /// Replace photo with cropped version (records in undo stack)
  Future<void> replacePhotoAfterCrop({
    required String id,
    required String newCroppedPath,
    required Uint8List newCroppedBytes,
    required int newWidth,
    required int newHeight,
  }) async {
    _pushUndoState();
    final updated = state.photos.map((p) {
      if (p.id == id) {
        return p.copyWith(
          path: newCroppedPath,
          cachedBytes: newCroppedBytes,
          width: newWidth,
          height: newHeight,
          originalSizeBytes: newCroppedBytes.lengthInBytes,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(photos: updated);
  }

  /// Flip photo horizontally
  void flipPhotoHorizontal(String id) {
    _pushUndoState();
    final updated = state.photos.map((p) {
      if (p.id == id) {
        return p.copyWith(
          isFlippedHorizontally: !p.isFlippedHorizontally,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(photos: updated);
  }

  /// Flip photo vertically
  void flipPhotoVertical(String id) {
    _pushUndoState();
    final updated = state.photos.map((p) {
      if (p.id == id) {
        return p.copyWith(
          isFlippedVertically: !p.isFlippedVertically,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(photos: updated);
  }

  /// Apply filter
  void applyPhotoFilter(String id, PhotoFilter filter) {
    _pushUndoState();
    final updated = state.photos.map((p) {
      if (p.id == id) {
        return p.copyWith(filter: filter);
      }
      return p;
    }).toList();
    state = state.copyWith(photos: updated);
  }

  /// Batch apply filter to all photos
  void applyFilterToAll(PhotoFilter filter) {
    _pushUndoState();
    final updated = state.photos.map((p) => p.copyWith(filter: filter)).toList();
    state = state.copyWith(photos: updated);
  }

  /// Update PDF export configuration
  void updateConfig(PdfExportConfig newConfig) {
    state = state.copyWith(config: newConfig);
  }

  /// Update layout mode immediately
  void updateLayout(PdfPhotoLayout layout) {
    state = state.copyWith(config: state.config.copyWith(layout: layout));
  }

  /// Undo last photo modification
  void undo() {
    if (!state.canUndo) return;
    final previousList = state.undoStack.last;
    final remainingUndo = state.undoStack.sublist(0, state.undoStack.length - 1);
    state = state.copyWith(
      photos: previousList,
      undoStack: remainingUndo,
      redoStack: [...state.redoStack, state.photos],
    );
  }

  /// Redo photo modification
  void redo() {
    if (!state.canRedo) return;
    final nextList = state.redoStack.last;
    final remainingRedo = state.redoStack.sublist(0, state.redoStack.length - 1);
    state = state.copyWith(
      photos: nextList,
      redoStack: remainingRedo,
      undoStack: [...state.undoStack, state.photos],
    );
  }

  /// Generate PDF document with progress reporting and storage validation
  Future<Uint8List?> generatePdf() async {
    if (state.photos.isEmpty) return null;

    // Check available storage threshold before generation (Requirement 3)
    final hasSpace = await FileUtils.hasSufficientStorage(minRequiredBytes: 50 * 1024 * 1024);
    if (!hasSpace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Not enough storage space to save the PDF.',
      );
      return null;
    }

    try {
      state = state.copyWith(
        isLoading: true,
        errorMessage: null,
        progressPercent: 0.0,
        progressMessage: 'Initializing document...',
      );

      final bytes = await PdfGeneratorService.generatePdf(
        photos: state.photos,
        config: state.config,
        onPageProgress: (currentPage, totalPages) {
          state = state.copyWith(
            progressMessage: 'Generating page $currentPage of $totalPages…',
            progressPercent: currentPage / totalPages,
          );
        },
      );

      state = state.copyWith(
        isLoading: false,
        generatedPdfBytes: bytes,
        progressMessage: null,
        progressPercent: 1.0,
      );
      return bytes;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'PDF generation failed: $e',
        progressMessage: null,
      );
      return null;
    }
  }

  /// Clear all photos
  void clearAll() {
    _pushUndoState();
    state = state.copyWith(photos: [], generatedPdfBytes: null);
  }
}

final photoToPdfProvider =
    StateNotifierProvider<PhotoToPdfController, PhotoToPdfState>((ref) {
  return PhotoToPdfController();
});
