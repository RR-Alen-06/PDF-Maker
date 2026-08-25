import 'dart:typed_data';
import 'package:flutter/widgets.dart' as fw;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../../core/constants/page_sizes.dart';
import '../domain/models/photo_item.dart';
import '../domain/models/pdf_export_config.dart';
import 'image_filter_service.dart';

typedef PdfProgressCallback = void Function(int currentPage, int totalPages);

class PdfGeneratorService {
  PdfGeneratorService._();

  /// Generates a complete multi-page PDF/1.4 document bytes from photo items and layout configuration.
  /// Reports real-time page generation progress through [onPageProgress].
  static Future<Uint8List> generatePdf({
    required List<PhotoItem> photos,
    required PdfExportConfig config,
    PdfProgressCallback? onPageProgress,
  }) async {
    final pdf = pw.Document(
      version: PdfVersion.pdf_1_4,
      compress: true,
      title: 'PDF Maker Document',
      author: 'Photo-to-PDF Maker Studio',
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

                // 2. Header
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

                // 3. Footer & Page Numbers
                if ((config.footerText != null && config.footerText!.trim().isNotEmpty) ||
                    config.includePageNumbers)
                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          config.footerText ?? '',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                        if (config.includePageNumbers)
                          pw.Text(
                            config.pageNumberFormat
                                .replaceAll('{page}', '${pageIndex + 1}')
                                .replaceAll('{total}', '$totalPages'),
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                          ),
                      ],
                    ),
                  ),

                // 4. Watermark Layer (Rotated diagonally across page center)
                if (config.watermarkText != null && config.watermarkText!.trim().isNotEmpty)
                  pw.Center(
                    child: pw.Transform.rotate(
                      angle: -0.785398, // -45 degrees
                      child: pw.Text(
                        config.watermarkText!,
                        style: pw.TextStyle(
                          color: PdfColor(0.7, 0.7, 0.7, config.watermarkOpacity),
                          fontSize: config.watermarkFontSize,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    Uint8List rawPdfBytes = await pdf.save();

    // 5. Password protection & security encryption if requested
    if (config.userPassword != null && config.userPassword!.isNotEmpty) {
      rawPdfBytes = _applyPasswordSecurity(
        rawPdfBytes: rawPdfBytes,
        userPassword: config.userPassword!,
        ownerPassword: config.ownerPassword ?? config.userPassword!,
      );
    }

    return rawPdfBytes;
  }

  /// Builds the visual grid layout according to selected PdfPhotoLayout.
  /// Partially filled slots are rendered with blank space.
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
