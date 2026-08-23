import 'package:flutter/material.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';

@immutable
class PdfExportConfig {
  final PageSizePreset pageSizePreset;
  final double customWidth;
  final double customHeight;
  final PageOrientation orientation;
  final PageMarginPreset marginPreset;
  final double customMarginPt;
  final double imageSpacingPt;
  final PdfPhotoLayout layout;
  final ImageQualityPreset qualityPreset;
  final BoxFit imageFit; // contain / cover
  final bool autoRotateOrientation;

  // Watermark and Header/Footer
  final String? watermarkText;
  final double watermarkOpacity;
  final double watermarkFontSize;
  final String? headerText;
  final String? footerText;
  final bool includePageNumbers;
  final String pageNumberFormat; // 'Page {page} of {total}'

  // Password Security
  final String? userPassword;
  final String? ownerPassword;

  const PdfExportConfig({
    this.pageSizePreset = PageSizePreset.a4,
    this.customWidth = 595.28,
    this.customHeight = 841.89,
    this.orientation = PageOrientation.portrait,
    this.marginPreset = PageMarginPreset.narrow,
    this.customMarginPt = 14.17,
    this.imageSpacingPt = 8.0,
    this.layout = PdfPhotoLayout.onePerPage,
    this.qualityPreset = ImageQualityPreset.high,
    this.imageFit = BoxFit.contain,
    this.autoRotateOrientation = false,
    this.watermarkText,
    this.watermarkOpacity = 0.2,
    this.watermarkFontSize = 36.0,
    this.headerText,
    this.footerText,
    this.includePageNumbers = true,
    this.pageNumberFormat = 'Page {page} of {total}',
    this.userPassword,
    this.ownerPassword,
  });

  PdfExportConfig copyWith({
    PageSizePreset? pageSizePreset,
    double? customWidth,
    double? customHeight,
    PageOrientation? orientation,
    PageMarginPreset? marginPreset,
    double? customMarginPt,
    double? imageSpacingPt,
    PdfPhotoLayout? layout,
    ImageQualityPreset? qualityPreset,
    BoxFit? imageFit,
    bool? autoRotateOrientation,
    String? watermarkText,
    double? watermarkOpacity,
    double? watermarkFontSize,
    String? headerText,
    String? footerText,
    bool? includePageNumbers,
    String? pageNumberFormat,
    String? userPassword,
    String? ownerPassword,
  }) {
    return PdfExportConfig(
      pageSizePreset: pageSizePreset ?? this.pageSizePreset,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      orientation: orientation ?? this.orientation,
      marginPreset: marginPreset ?? this.marginPreset,
      customMarginPt: customMarginPt ?? this.customMarginPt,
      imageSpacingPt: imageSpacingPt ?? this.imageSpacingPt,
      layout: layout ?? this.layout,
      qualityPreset: qualityPreset ?? this.qualityPreset,
      imageFit: imageFit ?? this.imageFit,
      autoRotateOrientation:
          autoRotateOrientation ?? this.autoRotateOrientation,
      watermarkText: watermarkText ?? this.watermarkText,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      watermarkFontSize: watermarkFontSize ?? this.watermarkFontSize,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      includePageNumbers: includePageNumbers ?? this.includePageNumbers,
      pageNumberFormat: pageNumberFormat ?? this.pageNumberFormat,
      userPassword: userPassword ?? this.userPassword,
      ownerPassword: ownerPassword ?? this.ownerPassword,
    );
  }
}
