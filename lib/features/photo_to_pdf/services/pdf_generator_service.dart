import 'dart:typed_data';
import 'package:flutter/widgets.dart' as fw;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../../core/constants/page_sizes.dart';
import '../domain/models/photo_item.dart';
import '../domain/models/pdf_export_config.dart';
import 'image_filter_service.dart';

class PdfGeneratorService {
  PdfGeneratorService._();

  /// Generates a complete multi-page PDF document bytes from photo items and layout configuration
  static Future<Uint8List> generatePdf({
    required List<PhotoItem> photos,
    required PdfExportConfig config,
  }) async {
    final pdf = pw.Document();

    final margin = config.marginPreset == PageMarginPreset.none
        ? 0.0
        : (config.marginPreset == PageMarginPreset.narrow
            ? 14.17
            : (config.marginPreset == PageMarginPreset.wide ? 56.70 : 28.35));

    final isLandscape = config.orientation == PageOrientation.landscape;
    final pageFormat = config.pageSizePreset.toPdfFormat(isLandscape: isLandscape);

    final photosPerPage = config.layout.photosPerPage;
    final totalPages = (photos.length / photosPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
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
          margin: pw.EdgeInsets.all(margin),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // 1. Photo Layout Grid
                _buildPhotoLayout(
                  images: processedImages,
                  layout: config.layout,
                  spacing: config.imageSpacingPt,
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

  /// Builds the visual grid layout according to selected PdfPhotoLayout
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
            if (images.length > 1) ...[
              pw.SizedBox(height: spacing),
              pw.Expanded(child: pw.Center(child: pw.Image(images[1], fit: fit))),
            ],
          ],
        );

      case PdfPhotoLayout.twoPerPageSideBySide:
        return pw.Row(
          children: [
            pw.Expanded(child: pw.Center(child: pw.Image(images[0], fit: fit))),
            if (images.length > 1) ...[
              pw.SizedBox(width: spacing),
              pw.Expanded(child: pw.Center(child: pw.Image(images[1], fit: fit))),
            ],
          ],
        );

      case PdfPhotoLayout.threePerPage:
        return pw.Column(
          children: [
            for (int i = 0; i < images.length; i++) ...[
              pw.Expanded(child: pw.Center(child: pw.Image(images[i], fit: fit))),
              if (i < images.length - 1) pw.SizedBox(height: spacing),
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
                  if (images.length > 1) ...[
                    pw.SizedBox(width: spacing),
                    pw.Expanded(child: pw.Center(child: pw.Image(images[1], fit: fit))),
                  ],
                ],
              ),
            ),
            if (images.length > 2) ...[
              pw.SizedBox(height: spacing),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Center(child: pw.Image(images[2], fit: fit))),
                    if (images.length > 3) ...[
                      pw.SizedBox(width: spacing),
                      pw.Expanded(child: pw.Center(child: pw.Image(images[3], fit: fit))),
                    ] else
                      pw.Spacer(),
                  ],
                ),
              ),
            ],
          ],
        );

      case PdfPhotoLayout.sixPerPageGrid:
        return pw.Column(
          children: [
            for (int row = 0; row < 3; row++) ...[
              if (row * 2 < images.length)
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      pw.Expanded(child: pw.Center(child: pw.Image(images[row * 2], fit: fit))),
                      if (row * 2 + 1 < images.length) ...[
                        pw.SizedBox(width: spacing),
                        pw.Expanded(child: pw.Center(child: pw.Image(images[row * 2 + 1], fit: fit))),
                      ] else
                        pw.Spacer(),
                    ],
                  ),
                ),
              if (row < 2 && (row + 1) * 2 < images.length)
                pw.SizedBox(height: spacing),
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
