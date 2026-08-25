import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';
import 'package:pdf_maker/features/tools/image_compressor/services/image_compressor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 7: Per-Photo Editing Unit Tests', () {
    test('PhotoToPdfController rotates photo CW and CCW accurately with undo support', () {
      final controller = PhotoToPdfController();
      controller.state = controller.state.copyWith(
        photos: [
          const PhotoItem(id: 'photo_1', path: '/p1.jpg', rotationDegrees: 0),
        ],
      );

      // Rotate CW
      controller.rotatePhoto('photo_1');
      expect(controller.state.photos.first.rotationDegrees, equals(90));

      // Rotate CW again
      controller.rotatePhoto('photo_1');
      expect(controller.state.photos.first.rotationDegrees, equals(180));

      // Rotate CCW
      controller.rotatePhotoCounterClockwise('photo_1');
      expect(controller.state.photos.first.rotationDegrees, equals(90));

      // Undo
      controller.undo();
      expect(controller.state.photos.first.rotationDegrees, equals(180));

      controller.undo();
      expect(controller.state.photos.first.rotationDegrees, equals(90));
    });

    test('PhotoToPdfController flips photo horizontally and vertically with undo support', () {
      final controller = PhotoToPdfController();
      controller.state = controller.state.copyWith(
        photos: [
          const PhotoItem(id: 'photo_1', path: '/p1.jpg'),
        ],
      );

      expect(controller.state.photos.first.isFlippedHorizontally, isFalse);
      controller.flipPhotoHorizontal('photo_1');
      expect(controller.state.photos.first.isFlippedHorizontally, isTrue);

      controller.flipPhotoVertical('photo_1');
      expect(controller.state.photos.first.isFlippedVertically, isTrue);

      controller.undo();
      expect(controller.state.photos.first.isFlippedVertically, isFalse);
      expect(controller.state.photos.first.isFlippedHorizontally, isTrue);
    });
  });

  group('Requirement 8: Page Setup & Persistence Unit Tests', () {
    test('Custom page size in mm converts accurately to PDF points', () {
      // 1 mm = 2.83465 pt
      // 100 mm x 200 mm custom size
      final format = PageSizePreset.custom.toPdfFormat(
        isLandscape: false,
        customWidthMm: 100.0,
        customHeightMm: 200.0,
      );

      expect(format.width, closeTo(283.465, 0.1));
      expect(format.height, closeTo(566.93, 0.1));

      final landscapeFormat = PageSizePreset.custom.toPdfFormat(
        isLandscape: true,
        customWidthMm: 100.0,
        customHeightMm: 200.0,
      );
      expect(landscapeFormat.width, closeTo(566.93, 0.1));
      expect(landscapeFormat.height, closeTo(283.465, 0.1));
    });

    test('PdfExportConfig persists and reloads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      const customConfig = PdfExportConfig(
        pageSizePreset: PageSizePreset.custom,
        customWidthMm: 150.0,
        customHeightMm: 250.0,
        orientation: PageOrientation.landscape,
        marginMm: 15.0,
        photoSpacingMm: 8.0,
        layout: PdfPhotoLayout.twoPerPageStacked,
      );

      await PdfExportConfig.saveToPreferences(customConfig);
      final loaded = await PdfExportConfig.loadFromPreferences();

      expect(loaded.pageSizePreset, equals(PageSizePreset.custom));
      expect(loaded.customWidthMm, equals(150.0));
      expect(loaded.customHeightMm, equals(250.0));
      expect(loaded.orientation, equals(PageOrientation.landscape));
      expect(loaded.marginMm, equals(15.0));
      expect(loaded.photoSpacingMm, equals(8.0));
      expect(loaded.layout, equals(PdfPhotoLayout.twoPerPageStacked));
    });
  });

  group('Requirement 9: Standalone Image Compressor Unit Tests', () {
    test('ImageCompressorService derives target quality correctly', () {
      const originalBytes = 1000 * 1024; // 1000 KB
      // Target 500 KB (50% reduction)
      final quality500 = ImageCompressorService.deriveQualityForTargetSize(
        originalSizeBytes: originalBytes,
        targetSizeKb: 500,
      );
      expect(quality500, greaterThanOrEqualTo(50));
      expect(quality500, lessThanOrEqualTo(70));

      // Target 200 KB
      final quality200 = ImageCompressorService.deriveQualityForTargetSize(
        originalSizeBytes: originalBytes,
        targetSizeKb: 200,
      );
      expect(quality200, lessThan(quality500));
    });

    test('ImageCompressorService estimates compressed size accurately', () {
      const originalBytes = 2000 * 1024; // 2 MB
      final estByQuality = ImageCompressorService.estimateCompressedSize(
        originalSizeBytes: originalBytes,
        quality: 50,
      );
      expect(estByQuality, lessThan(originalBytes));

      final estByTarget = ImageCompressorService.estimateCompressedSize(
        originalSizeBytes: originalBytes,
        quality: 80,
        targetSizeKb: 300,
      );
      expect(estByTarget, equals(300 * 1024));
    });
  });
}
