import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';

void main() {
  group('Layout and Export Configuration Unit Tests', () {
    test('PdfPhotoLayout calculates photos per page correctly', () {
      expect(PdfPhotoLayout.onePerPage.photosPerPage, equals(1));
      expect(PdfPhotoLayout.twoPerPageStacked.photosPerPage, equals(2));
      expect(PdfPhotoLayout.twoPerPageSideBySide.photosPerPage, equals(2));
      expect(PdfPhotoLayout.threePerPage.photosPerPage, equals(3));
      expect(PdfPhotoLayout.fourPerPageGrid.photosPerPage, equals(4));
      expect(PdfPhotoLayout.sixPerPageGrid.photosPerPage, equals(6));
    });

    test('PageSizePreset converts to portrait and landscape formats accurately', () {
      final a4Portrait = PageSizePreset.a4.toPdfFormat(isLandscape: false);
      expect(a4Portrait.width, closeTo(595.28, 0.01));
      expect(a4Portrait.height, closeTo(841.89, 0.01));

      final a4Landscape = PageSizePreset.a4.toPdfFormat(isLandscape: true);
      expect(a4Landscape.width, closeTo(841.89, 0.01));
      expect(a4Landscape.height, closeTo(595.28, 0.01));
    });

    test('PdfExportConfig copyWith operates immutably', () {
      const config = PdfExportConfig();
      final updated = config.copyWith(
        watermarkText: 'TEST_WATERMARK',
        orientation: PageOrientation.landscape,
      );

      expect(updated.watermarkText, equals('TEST_WATERMARK'));
      expect(updated.orientation, equals(PageOrientation.landscape));
      expect(config.watermarkText, isNull);
    });
  });
}
