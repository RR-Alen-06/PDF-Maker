import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/overlay_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';

void main() {
  group('Requirement 11: Overlay Settings Unit Tests', () {
    test('PageNumberFormatPreset formats accurately', () {
      expect(PageNumberFormatPreset.numberOnly.format(1, 10), equals('1'));
      expect(PageNumberFormatPreset.pageNumber.format(3, 10), equals('Page 3'));
      expect(PageNumberFormatPreset.pageNOfTotal.format(4, 10), equals('Page 4 of 10'));
      expect(PageNumberFormatPreset.nOfTotal.format(7, 10), equals('7/10'));
    });

    test('DateStampFormatPreset formats dates correctly across presets', () {
      final date = DateTime(2026, 8, 25);
      expect(DateStampFormatPreset.ddMmYyyy.format(date), equals('25/08/2026'));
      expect(DateStampFormatPreset.mmDdHyyy.format(date), equals('08/25/2026'));
      expect(DateStampFormatPreset.yyyyMmDd.format(date), equals('2026-08-25'));
    });

    test('PdfExportConfig identifies overlay position conflicts', () {
      // Different positions -> no conflict
      const safeConfig = PdfExportConfig(
        enablePageNumbers: true,
        pageNumberPosition: OverlayGridPosition.bottomRight,
        enableDateStamp: true,
        dateStampPosition: OverlayGridPosition.bottomLeft,
      );
      expect(safeConfig.hasOverlayPositionConflict, isFalse);

      // Same position -> conflict detected
      const conflictingConfig = PdfExportConfig(
        enablePageNumbers: true,
        pageNumberPosition: OverlayGridPosition.bottomRight,
        enableDateStamp: true,
        dateStampPosition: OverlayGridPosition.bottomRight,
      );
      expect(conflictingConfig.hasOverlayPositionConflict, isTrue);

      // Same position but date stamp disabled -> no conflict
      const disabledDateConfig = PdfExportConfig(
        enablePageNumbers: true,
        pageNumberPosition: OverlayGridPosition.bottomRight,
        enableDateStamp: false,
        dateStampPosition: OverlayGridPosition.bottomRight,
      );
      expect(disabledDateConfig.hasOverlayPositionConflict, isFalse);
    });
  });
}
