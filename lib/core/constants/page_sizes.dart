import 'package:pdf/pdf.dart';

enum PageSizePreset {
  a4('A4', 595.28, 841.89),
  letter('US Letter', 612.0, 792.0),
  legal('US Legal', 612.0, 1008.0),
  a3('A3', 841.89, 1190.55),
  a5('A5', 419.53, 595.28),
  businessCard('Business Card (3.5x2")', 252.0, 144.0),
  custom('Custom', 0, 0);

  final String label;
  final double width;
  final double height;

  const PageSizePreset(this.label, this.width, this.height);

  PdfPageFormat toPdfFormat({bool isLandscape = false}) {
    if (this == PageSizePreset.custom) {
      return isLandscape
          ? const PdfPageFormat(841.89, 595.28)
          : const PdfPageFormat(595.28, 841.89);
    }
    return isLandscape
        ? PdfPageFormat(height, width)
        : PdfPageFormat(width, height);
  }
}

enum PageOrientation {
  portrait('Portrait'),
  landscape('Landscape'),
  auto('Auto (Match Photo)');

  final String label;
  const PageOrientation(this.label);
}

enum PageMarginPreset {
  none('None (0 mm)', 0.0),
  narrow('Narrow (5 mm)', 14.17),
  normal('Normal (10 mm)', 28.35),
  wide('Wide (20 mm)', 56.70);

  final String label;
  final double ptValue;

  const PageMarginPreset(this.label, this.ptValue);
}

enum PdfPhotoLayout {
  onePerPage('1 per page', 1, 1),
  twoPerPageSideBySide('2 per page (Side-by-side)', 2, 1),
  twoPerPageStacked('2 per page (Stacked)', 1, 2),
  threePerPage('3 per page', 1, 3),
  fourPerPageGrid('4 per page (2x2 Grid)', 2, 2),
  sixPerPageGrid('6 per page (2x3 Grid)', 2, 3);

  final String label;
  final int columns;
  final int rows;

  const PdfPhotoLayout(this.label, this.columns, this.rows);

  int get photosPerPage => columns * rows;
}

enum ImageQualityPreset {
  low('Low (Fast / Compact)', 40, 96),
  medium('Medium (Balanced)', 70, 150),
  high('High (Print Ready)', 85, 220),
  original('Original (Lossless)', 100, 300);

  final String label;
  final int quality;
  final int dpi;

  const ImageQualityPreset(this.label, this.quality, this.dpi);
}
