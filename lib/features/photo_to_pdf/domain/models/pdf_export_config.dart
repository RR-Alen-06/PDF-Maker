import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'overlay_config.dart';

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

  // Header and Footer Text (Legacy & Extra)
  final String? headerText;
  final String? footerText;

  // Requirement 11: Overlay Settings (Independently toggled)
  // 1. Page Numbers
  final bool enablePageNumbers;
  final PageNumberFormatPreset pageNumberFormatPreset;
  final OverlayGridPosition pageNumberPosition;
  final double pageNumberFontSize; // 8 - 36 pt, step 2

  // 2. Date Stamp
  final bool enableDateStamp;
  final DateStampSource dateStampSource;
  final DateTime? customDate;
  final DateStampFormatPreset dateStampFormatPreset;
  final OverlayGridPosition dateStampPosition;
  final double dateStampFontSize;

  // 3. Watermark Text
  final bool enableWatermark;
  final String? watermarkText; // max 100 characters
  final String watermarkFont;
  final double watermarkOpacity; // 0.1 to 1.0 (10% - 100%)
  final double watermarkRotationAngle; // 0 - 360 deg
  final OverlayGridPosition watermarkPosition;
  final double watermarkFontSize;

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
    this.headerText,
    this.footerText,

    // Overlay defaults
    this.enablePageNumbers = true,
    this.pageNumberFormatPreset = PageNumberFormatPreset.pageNOfTotal,
    this.pageNumberPosition = OverlayGridPosition.bottomRight,
    this.pageNumberFontSize = 10.0,

    this.enableDateStamp = false,
    this.dateStampSource = DateStampSource.auto,
    this.customDate,
    this.dateStampFormatPreset = DateStampFormatPreset.yyyyMmDd,
    this.dateStampPosition = OverlayGridPosition.bottomLeft,
    this.dateStampFontSize = 10.0,

    this.enableWatermark = false,
    this.watermarkText,
    this.watermarkFont = 'Helvetica',
    this.watermarkOpacity = 0.2,
    this.watermarkRotationAngle = 315.0, // diagonal
    this.watermarkPosition = OverlayGridPosition.middleCenter,
    this.watermarkFontSize = 36.0,

    this.userPassword,
    this.ownerPassword,
  });

  /// Check if Page Numbers and Date Stamp overlap in grid position
  bool get hasOverlayPositionConflict =>
      enablePageNumbers &&
      enableDateStamp &&
      pageNumberPosition == dateStampPosition;

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
    String? headerText,
    String? footerText,
    bool? enablePageNumbers,
    PageNumberFormatPreset? pageNumberFormatPreset,
    OverlayGridPosition? pageNumberPosition,
    double? pageNumberFontSize,
    bool? enableDateStamp,
    DateStampSource? dateStampSource,
    DateTime? customDate,
    DateStampFormatPreset? dateStampFormatPreset,
    OverlayGridPosition? dateStampPosition,
    double? dateStampFontSize,
    bool? enableWatermark,
    String? watermarkText,
    String? watermarkFont,
    double? watermarkOpacity,
    double? watermarkRotationAngle,
    OverlayGridPosition? watermarkPosition,
    double? watermarkFontSize,
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
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      enablePageNumbers: enablePageNumbers ?? this.enablePageNumbers,
      pageNumberFormatPreset:
          pageNumberFormatPreset ?? this.pageNumberFormatPreset,
      pageNumberPosition: pageNumberPosition ?? this.pageNumberPosition,
      pageNumberFontSize: pageNumberFontSize ?? this.pageNumberFontSize,
      enableDateStamp: enableDateStamp ?? this.enableDateStamp,
      dateStampSource: dateStampSource ?? this.dateStampSource,
      customDate: customDate ?? this.customDate,
      dateStampFormatPreset:
          dateStampFormatPreset ?? this.dateStampFormatPreset,
      dateStampPosition: dateStampPosition ?? this.dateStampPosition,
      dateStampFontSize: dateStampFontSize ?? this.dateStampFontSize,
      enableWatermark: enableWatermark ?? this.enableWatermark,
      watermarkText: watermarkText ?? this.watermarkText,
      watermarkFont: watermarkFont ?? this.watermarkFont,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      watermarkRotationAngle:
          watermarkRotationAngle ?? this.watermarkRotationAngle,
      watermarkPosition: watermarkPosition ?? this.watermarkPosition,
      watermarkFontSize: watermarkFontSize ?? this.watermarkFontSize,
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
      'headerText': headerText,
      'footerText': footerText,
      'enablePageNumbers': enablePageNumbers,
      'pageNumberFormatPreset': pageNumberFormatPreset.name,
      'pageNumberPosition': pageNumberPosition.name,
      'pageNumberFontSize': pageNumberFontSize,
      'enableDateStamp': enableDateStamp,
      'dateStampSource': dateStampSource.name,
      'customDate': customDate?.toIso8601String(),
      'dateStampFormatPreset': dateStampFormatPreset.name,
      'dateStampPosition': dateStampPosition.name,
      'dateStampFontSize': dateStampFontSize,
      'enableWatermark': enableWatermark,
      'watermarkText': watermarkText,
      'watermarkFont': watermarkFont,
      'watermarkOpacity': watermarkOpacity,
      'watermarkRotationAngle': watermarkRotationAngle,
      'watermarkPosition': watermarkPosition.name,
      'watermarkFontSize': watermarkFontSize,
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
      headerText: json['headerText'] as String?,
      footerText: json['footerText'] as String?,
      enablePageNumbers: json['enablePageNumbers'] as bool? ?? true,
      pageNumberFormatPreset: PageNumberFormatPreset.values.firstWhere(
        (e) => e.name == json['pageNumberFormatPreset'],
        orElse: () => PageNumberFormatPreset.pageNOfTotal,
      ),
      pageNumberPosition: OverlayGridPosition.values.firstWhere(
        (e) => e.name == json['pageNumberPosition'],
        orElse: () => OverlayGridPosition.bottomRight,
      ),
      pageNumberFontSize: (json['pageNumberFontSize'] as num?)?.toDouble() ?? 10.0,
      enableDateStamp: json['enableDateStamp'] as bool? ?? false,
      dateStampSource: DateStampSource.values.firstWhere(
        (e) => e.name == json['dateStampSource'],
        orElse: () => DateStampSource.auto,
      ),
      customDate: json['customDate'] != null
          ? DateTime.tryParse(json['customDate'] as String)
          : null,
      dateStampFormatPreset: DateStampFormatPreset.values.firstWhere(
        (e) => e.name == json['dateStampFormatPreset'],
        orElse: () => DateStampFormatPreset.yyyyMmDd,
      ),
      dateStampPosition: OverlayGridPosition.values.firstWhere(
        (e) => e.name == json['dateStampPosition'],
        orElse: () => OverlayGridPosition.bottomLeft,
      ),
      dateStampFontSize: (json['dateStampFontSize'] as num?)?.toDouble() ?? 10.0,
      enableWatermark: json['enableWatermark'] as bool? ?? false,
      watermarkText: json['watermarkText'] as String?,
      watermarkFont: json['watermarkFont'] as String? ?? 'Helvetica',
      watermarkOpacity: (json['watermarkOpacity'] as num?)?.toDouble() ?? 0.2,
      watermarkRotationAngle:
          (json['watermarkRotationAngle'] as num?)?.toDouble() ?? 315.0,
      watermarkPosition: OverlayGridPosition.values.firstWhere(
        (e) => e.name == json['watermarkPosition'],
        orElse: () => OverlayGridPosition.middleCenter,
      ),
      watermarkFontSize: (json['watermarkFontSize'] as num?)?.toDouble() ?? 36.0,
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
