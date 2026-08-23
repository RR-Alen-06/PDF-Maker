import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/services/pdf_generator_service.dart';

@immutable
class PhotoToPdfState {
  final List<PhotoItem> photos;
  final PdfExportConfig config;
  final bool isLoading;
  final String? errorMessage;
  final Uint8List? generatedPdfBytes;
  final List<List<PhotoItem>> undoStack;
  final List<List<PhotoItem>> redoStack;

  const PhotoToPdfState({
    this.photos = const [],
    this.config = const PdfExportConfig(),
    this.isLoading = false,
    this.errorMessage,
    this.generatedPdfBytes,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  PhotoToPdfState copyWith({
    List<PhotoItem>? photos,
    PdfExportConfig? config,
    bool? isLoading,
    String? errorMessage,
    Uint8List? generatedPdfBytes,
    List<List<PhotoItem>>? undoStack,
    List<List<PhotoItem>>? redoStack,
  }) {
    return PhotoToPdfState(
      photos: photos ?? this.photos,
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
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

  /// Pick photos from gallery
  Future<void> pickPhotosFromGallery() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      await _addPhotosFromFiles(pickedFiles);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to pick photos: $e',
      );
    }
  }

  /// Pick single photo from camera
  Future<void> takePhotoFromCamera() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      await _addPhotosFromFiles([pickedFile]);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to take photo: $e',
      );
    }
  }

  Future<void> _addPhotosFromFiles(List<XFile> files) async {
    _pushUndoState();
    final newItems = <PhotoItem>[];

    for (final file in files) {
      final bytes = await File(file.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      final id = DateTime.now().microsecondsSinceEpoch.toString();

      newItems.add(
        PhotoItem(
          id: id,
          path: file.path,
          cachedBytes: bytes,
          width: decoded?.width ?? 0,
          height: decoded?.height ?? 0,
          originalSizeBytes: bytes.lengthInBytes,
        ),
      );
    }

    state = state.copyWith(
      photos: [...state.photos, ...newItems],
      isLoading: false,
    );
  }

  /// Reorder photos in the list
  void reorderPhotos(int oldIndex, int newIndex) {
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

  /// Apply filter (Grayscale, B&W scan, Enhanced)
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

  /// Update layout mode
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

  /// Generate PDF document
  Future<Uint8List?> generatePdf() async {
    if (state.photos.isEmpty) return null;
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final bytes = await PdfGeneratorService.generatePdf(
        photos: state.photos,
        config: state.config,
      );
      state = state.copyWith(
        isLoading: false,
        generatedPdfBytes: bytes,
      );
      return bytes;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to generate PDF: $e',
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
