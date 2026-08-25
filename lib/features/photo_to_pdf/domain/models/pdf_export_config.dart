import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';

@immutable
class PdfExportConfig {
  final PageSizePreset pageSizePreset;
  final double customWidthMm; // 50 to 1189 mm
  final double customHeightMm; // 50 to 1189 mm
  final PageOrientation orientation;
  final double marginMm; // 0 to 50 mm
  final double photoSpacingMm; // 0 to 20 mm
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
    this.customWidthMm = 210.0,
    this.customHeightMm = 297.0,
    this.orientation = PageOrientation.portrait,
    this.marginMm = 5.0,
    this.photoSpacingMm = 3.0,
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

  /// Convert margin in mm to points (1 mm = 2.83465 pt)
  double get marginPt => marginMm * 2.83465;

  /// Convert photo spacing in mm to points (1 mm = 2.83465 pt)
  double get photoSpacingPt => photoSpacingMm * 2.83465;

  PdfExportConfig copyWith({
    PageSizePreset? pageSizePreset,
    double? customWidthMm,
    double? customHeightMm,
    PageOrientation? orientation,
    double? marginMm,
    double? photoSpacingMm,
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
      customWidthMm: customWidthMm ?? this.customWidthMm,
      customHeightMm: customHeightMm ?? this.customHeightMm,
      orientation: orientation ?? this.orientation,
      marginMm: marginMm ?? this.marginMm,
      photoSpacingMm: photoSpacingMm ?? this.photoSpacingMm,
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

  Map<String, dynamic> toJson() {
    return {
      'pageSizePreset': pageSizePreset.name,
      'customWidthMm': customWidthMm,
      'customHeightMm': customHeightMm,
      'orientation': orientation.name,
      'marginMm': marginMm,
      'photoSpacingMm': photoSpacingMm,
      'layout': layout.name,
      'qualityPreset': qualityPreset.name,
      'includePageNumbers': includePageNumbers,
      'watermarkText': watermarkText,
      'headerText': headerText,
      'footerText': footerText,
    };
  }

  factory PdfExportConfig.fromJson(Map<String, dynamic> json) {
    return PdfExportConfig(
      pageSizePreset: PageSizePreset.values.firstWhere(
        (e) => e.name == json['pageSizePreset'],
        orElse: () => PageSizePreset.a4,
      ),
      customWidthMm: (json['customWidthMm'] as num?)?.toDouble() ?? 210.0,
      customHeightMm: (json['customHeightMm'] as num?)?.toDouble() ?? 297.0,
      orientation: PageOrientation.values.firstWhere(
        (e) => e.name == json['orientation'],
        orElse: () => PageOrientation.portrait,
      ),
      marginMm: (json['marginMm'] as num?)?.toDouble() ?? 5.0,
      photoSpacingMm: (json['photoSpacingMm'] as num?)?.toDouble() ?? 3.0,
      layout: PdfPhotoLayout.values.firstWhere(
        (e) => e.name == json['layout'],
        orElse: () => PdfPhotoLayout.onePerPage,
      ),
      qualityPreset: ImageQualityPreset.values.firstWhere(
        (e) => e.name == json['qualityPreset'],
        orElse: () => ImageQualityPreset.high,
      ),
      includePageNumbers: json['includePageNumbers'] as bool? ?? true,
      watermarkText: json['watermarkText'] as String?,
      headerText: json['headerText'] as String?,
      footerText: json['footerText'] as String?,
    );
  }

  /// Save page setup configuration to shared preferences
  static Future<void> saveToPreferences(PdfExportConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(config.toJson());
    await prefs.setString('pdf_maker_page_setup', jsonStr);
  }

  /// Load page setup configuration from shared preferences
  static Future<PdfExportConfig> loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('pdf_maker_page_setup');
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return PdfExportConfig.fromJson(decoded);
      } catch (_) {}
    }
    return const PdfExportConfig();
  }
}
