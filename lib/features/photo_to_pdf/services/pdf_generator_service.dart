import 'dart:typed_data';
import 'package:flutter/widgets.dart' as fw;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../../core/constants/page_sizes.dart';
import '../domain/models/photo_item.dart';
import '../domain/models/pdf_export_config.dart';
import '../domain/models/overlay_config.dart';
import 'image_filter_service.dart';

typedef PdfProgressCallback = void Function(int currentPage, int totalPages);

class PdfGeneratorService {
  PdfGeneratorService._();

  /// Generates a complete multi-page PDF/1.4 document bytes from photo items and layout configuration.
  /// Reports real-time page generation progress through [onPageProgress].
  static Future<Uint8List> generatePdf({
    required List<PhotoItem> photos,
    required PdfExportConfig config,
    String? documentTitle,
    PdfProgressCallback? onPageProgress,
  }) async {
    final cleanTitle = documentTitle ?? 'PDF Maker Document';
    final pdf = pw.Document(
      version: PdfVersion.pdf_1_4,
      compress: true,
      title: cleanTitle,
      author: 'Photo-to-PDF Maker Studio',
      creator: 'PDF Maker Studio v1.0.0',
      subject: 'Converted Photos PDF Document',
    );

    final marginPt = config.marginPt;
    final spacingPt = config.photoSpacingPt;

    final isLandscape = config.orientation == PageOrientation.landscape;
    final pageFormat = config.pageSizePreset.toPdfFormat(
      isLandscape: isLandscape,
      customWidthMm: config.customWidthMm,
      customHeightMm: config.customHeightMm,
    );

    final photosPerPage = config.layout.photosPerPage;
    final totalPages = (photos.length / photosPerPage).ceil();

    final exportDate = config.dateStampSource == DateStampSource.custom && config.customDate != null
        ? config.customDate!
        : DateTime.now();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      onPageProgress?.call(pageIndex + 1, totalPages);

      final startIndex = pageIndex * photosPerPage;
      final endIndex = (startIndex + photosPerPage > photos.length)
          ? photos.length
          : startIndex + photosPerPage;
      final pagePhotos = photos.sublist(startIndex, endIndex);

      // Pre-process image bytes for this page
      final processedImages = <pw.MemoryImage>[];
      for (final photo in pagePhotos) {
        final processedBytes = await ImageFilterService.processImage(photo);
        processedImages.add(pw.MemoryImage(processedBytes));
      }

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(marginPt),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // 1. Photo Layout Grid with empty slots filled with blank area
                _buildPhotoLayout(
                  images: processedImages,
                  layout: config.layout,
                  spacing: spacingPt,
                  fit: config.imageFit == fw.BoxFit.cover
                      ? pw.BoxFit.cover
                      : pw.BoxFit.contain,
                ),

                // 2. Header (if specified)
                if (config.headerText != null && config.headerText!.trim().isNotEmpty)
                  pw.Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: pw.Text(
                      config.headerText!,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),

                // 3. Footer (if specified)
                if (config.footerText != null && config.footerText!.trim().isNotEmpty)
                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.Text(
                      config.footerText!,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),

                // 4. Watermark Layer (Independent 9-position, angle, opacity)
                if (config.enableWatermark &&
                    config.watermarkText != null &&
                    config.watermarkText!.trim().isNotEmpty)
                  _buildWatermarkOverlay(config),

                // 5. Date Stamp Layer (Independent 9-position, format, font size)
                if (config.enableDateStamp)
                  _buildDateStampOverlay(config, exportDate),

                // 6. Page Numbers Layer (Independent 9-position, format, font size)
                if (config.enablePageNumbers)
                  _buildPageNumberOverlay(config, pageIndex + 1, totalPages),
              ],
            );
          },
        ),
      );
    }

    Uint8List rawPdfBytes = await pdf.save();

    // 7. Password protection & security encryption if requested
    if (config.userPassword != null && config.userPassword!.isNotEmpty) {
      rawPdfBytes = _applyPasswordSecurity(
        rawPdfBytes: rawPdfBytes,
        userPassword: config.userPassword!,
        ownerPassword: config.ownerPassword ?? config.userPassword!,
      );
    }

    return rawPdfBytes;
  }

  /// Positions an element according to 9-cell grid
  static pw.Alignment _gridPositionToAlignment(OverlayGridPosition pos) {
    switch (pos) {
      case OverlayGridPosition.topLeft:
        return pw.Alignment.topLeft;
      case OverlayGridPosition.topCenter:
        return pw.Alignment.topCenter;
      case OverlayGridPosition.topRight:
        return pw.Alignment.topRight;
      case OverlayGridPosition.middleLeft:
        return pw.Alignment.centerLeft;
      case OverlayGridPosition.middleCenter:
        return pw.Alignment.center;
      case OverlayGridPosition.middleRight:
        return pw.Alignment.centerRight;
      case OverlayGridPosition.bottomLeft:
        return pw.Alignment.bottomLeft;
      case OverlayGridPosition.bottomCenter:
        return pw.Alignment.bottomCenter;
      case OverlayGridPosition.bottomRight:
        return pw.Alignment.bottomRight;
    }
  }

  static pw.Widget _buildPageNumberOverlay(
    PdfExportConfig config,
    int currentPage,
    int totalPages,
  ) {
    final text = config.pageNumberFormatPreset.format(currentPage, totalPages);
    return pw.Align(
      alignment: _gridPositionToAlignment(config.pageNumberPosition),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: config.pageNumberFontSize,
          color: PdfColors.grey700,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildDateStampOverlay(
    PdfExportConfig config,
    DateTime date,
  ) {
    final text = config.dateStampFormatPreset.format(date);
    return pw.Align(
      alignment: _gridPositionToAlignment(config.dateStampPosition),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: config.dateStampFontSize,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  static pw.Widget _buildWatermarkOverlay(PdfExportConfig config) {
    final radians = (config.watermarkRotationAngle * 3.141592653589793) / 180.0;
    return pw.Align(
      alignment: _gridPositionToAlignment(config.watermarkPosition),
      child: pw.Transform.rotate(
        angle: radians,
        child: pw.Text(
          config.watermarkText!,
          style: pw.TextStyle(
            color: PdfColor(0.5, 0.5, 0.5, config.watermarkOpacity.clamp(0.05, 1.0)),
            fontSize: config.watermarkFontSize,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  /// Builds the visual grid layout according to selected PdfPhotoLayout.
  static pw.Widget _buildPhotoLayout({
    required List<pw.MemoryImage> images,
    required PdfPhotoLayout layout,
    required double spacing,
    required pw.BoxFit fit,
  }) {
    if (images.isEmpty) return pw.Container();

    switch (layout) {
      case PdfPhotoLayout.onePerPage:
        return pw.Center(
          child: pw.Image(images[0], fit: fit),
        );

      case PdfPhotoLayout.twoPerPageStacked:
        return pw.Column(
          children: [
            pw.Expanded(child: pw.Center(child: pw.Image(images[0], fit: fit))),
            pw.SizedBox(height: spacing),
            pw.Expanded(
              child: images.length > 1
                  ? pw.Center(child: pw.Image(images[1], fit: fit))
                  : pw.Container(),
            ),
          ],
        );

      case PdfPhotoLayout.twoPerPageSideBySide:
        return pw.Row(
          children: [
            pw.Expanded(child: pw.Center(child: pw.Image(images[0], fit: fit))),
            pw.SizedBox(width: spacing),
            pw.Expanded(
              child: images.length > 1
                  ? pw.Center(child: pw.Image(images[1], fit: fit))
                  : pw.Container(),
            ),
          ],
        );

      case PdfPhotoLayout.threePerPage:
        return pw.Column(
          children: [
            for (int i = 0; i < 3; i++) ...[
              pw.Expanded(
                child: i < images.length
                    ? pw.Center(child: pw.Image(images[i], fit: fit))
                    : pw.Container(),
              ),
              if (i < 2) pw.SizedBox(height: spacing),
            ],
          ],
        );

      case PdfPhotoLayout.fourPerPageGrid:
        return pw.Column(
          children: [
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Center(child: pw.Image(images[0], fit: fit))),
                  pw.SizedBox(width: spacing),
                  pw.Expanded(
                    child: images.length > 1
                        ? pw.Center(child: pw.Image(images[1], fit: fit))
                        : pw.Container(),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: spacing),
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: images.length > 2
                        ? pw.Center(child: pw.Image(images[2], fit: fit))
                        : pw.Container(),
                  ),
                  pw.SizedBox(width: spacing),
                  pw.Expanded(
                    child: images.length > 3
                        ? pw.Center(child: pw.Image(images[3], fit: fit))
                        : pw.Container(),
                  ),
                ],
              ),
            ),
          ],
        );

      case PdfPhotoLayout.sixPerPageGrid:
        return pw.Column(
          children: [
            for (int row = 0; row < 3; row++) ...[
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: row * 2 < images.length
                          ? pw.Center(child: pw.Image(images[row * 2], fit: fit))
                          : pw.Container(),
                    ),
                    pw.SizedBox(width: spacing),
                    pw.Expanded(
                      child: row * 2 + 1 < images.length
                          ? pw.Center(child: pw.Image(images[row * 2 + 1], fit: fit))
                          : pw.Container(),
                    ),
                  ],
                ),
              ),
              if (row < 2) pw.SizedBox(height: spacing),
            ],
          ],
        );
    }
  }

  /// Encrypts the PDF with user and owner passwords
  static Uint8List _applyPasswordSecurity({
    required Uint8List rawPdfBytes,
    required String userPassword,
    required String ownerPassword,
  }) {
    final sfDocument = sf.PdfDocument(inputBytes: rawPdfBytes);
    final security = sfDocument.security;
    security.userPassword = userPassword;
    security.ownerPassword = ownerPassword;
    security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    security.permissions.addAll([
      sf.PdfPermissionsFlags.print,
      sf.PdfPermissionsFlags.copyContent,
    ]);

    final List<int> securedBytes = sfDocument.saveSync();
    sfDocument.dispose();
    return Uint8List.fromList(securedBytes);
  }
}
