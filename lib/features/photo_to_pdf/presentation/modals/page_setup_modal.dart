import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';

class PageSetupModal extends StatefulWidget {
  final PdfExportConfig initialConfig;
  final ValueChanged<PdfExportConfig> onSave;

  const PageSetupModal({
    super.key,
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<PageSetupModal> createState() => _PageSetupModalState();
}

class _PageSetupModalState extends State<PageSetupModal> {
  late PageSizePreset _pageSize;
  late double _customWidthMm;
  late double _customHeightMm;
  late PageOrientation _orientation;
  late double _marginMm;
  late double _photoSpacingMm;
  late ImageQualityPreset _qualityPreset;
  late BoxFit _imageFit;
  late bool _includePageNumbers;

  late TextEditingController _customWidthController;
  late TextEditingController _customHeightController;
  late TextEditingController _watermarkController;
  late TextEditingController _headerController;
  late TextEditingController _footerController;
  late TextEditingController _userPasswordController;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _pageSize = c.pageSizePreset;
    _customWidthMm = c.customWidthMm;
    _customHeightMm = c.customHeightMm;
    _orientation = c.orientation;
    _marginMm = c.marginMm;
    _photoSpacingMm = c.photoSpacingMm;
    _qualityPreset = c.qualityPreset;
    _imageFit = c.imageFit;
    _includePageNumbers = c.enablePageNumbers;

    _customWidthController = TextEditingController(text: _customWidthMm.toStringAsFixed(0));
    _customHeightController = TextEditingController(text: _customHeightMm.toStringAsFixed(0));
    _watermarkController = TextEditingController(text: c.watermarkText ?? '');
    _headerController = TextEditingController(text: c.headerText ?? '');
    _footerController = TextEditingController(text: c.footerText ?? '');
    _userPasswordController = TextEditingController(text: c.userPassword ?? '');
  }

  @override
  void dispose() {
    _customWidthController.dispose();
    _customHeightController.dispose();
    _watermarkController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    _userPasswordController.dispose();
    super.dispose();
  }

  Future<void> _applyChanges() async {
    final parsedW = double.tryParse(_customWidthController.text.trim()) ?? _customWidthMm;
    final parsedH = double.tryParse(_customHeightController.text.trim()) ?? _customHeightMm;

    final clampedW = parsedW.clamp(50.0, 1189.0);
    final clampedH = parsedH.clamp(50.0, 1189.0);

    final updated = widget.initialConfig.copyWith(
      pageSizePreset: _pageSize,
      customWidthMm: clampedW,
      customHeightMm: clampedH,
      orientation: _orientation,
      marginMm: _marginMm.clamp(0.0, 50.0),
      photoSpacingMm: _photoSpacingMm.clamp(0.0, 20.0),
      qualityPreset: _qualityPreset,
      imageFit: _imageFit,
      enablePageNumbers: _includePageNumbers,
      watermarkText: _watermarkController.text.trim().isEmpty ? null : _watermarkController.text.trim(),
      headerText: _headerController.text.trim().isEmpty ? null : _headerController.text.trim(),
      footerText: _footerController.text.trim().isEmpty ? null : _footerController.text.trim(),
      userPassword: _userPasswordController.text.trim().isEmpty ? null : _userPasswordController.text.trim(),
    );

    // Persist to shared_preferences for subsequent sessions
    await PdfExportConfig.saveToPreferences(updated);

    widget.onSave(updated);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page & Document Setup',
                  style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // Page Size (A4, US Letter, US Legal, A3, A5, Custom mm)
            const Text('Page Size', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<PageSizePreset>(
              initialValue: _pageSize,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: PageSizePreset.values.map((p) {
                return DropdownMenuItem(value: p, child: Text(p.label));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _pageSize = val);
              },
            ),

            // Custom Page Size Fields in mm (Accepts 50 to 1189 mm)
            if (_pageSize == PageSizePreset.custom) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Width (mm)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _customWidthController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '50 - 1189',
                            suffixText: 'mm',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Height (mm)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _customHeightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '50 - 1189',
                            suffixText: 'mm',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Orientation
            const Text('Orientation', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<PageOrientation>(
              initialValue: _orientation,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: PageOrientation.values.map((o) {
                return DropdownMenuItem(value: o, child: Text(o.label));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _orientation = val);
              },
            ),
            const SizedBox(height: 16),

            // Margin Slider (0 - 50 mm, step 1 mm)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Page Margin', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_marginMm.round()} mm',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            Slider(
              value: _marginMm,
              min: 0,
              max: 50,
              divisions: 50,
              onChanged: (val) => setState(() => _marginMm = val),
            ),
            const SizedBox(height: 8),

            // Photo Spacing Slider (0 - 20 mm, step 1 mm)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Photo Spacing', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_photoSpacingMm.round()} mm',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            Slider(
              value: _photoSpacingMm,
              min: 0,
              max: 20,
              divisions: 20,
              onChanged: (val) => setState(() => _photoSpacingMm = val),
            ),
            const SizedBox(height: 16),

            // Watermark
            const Text('Watermark Text (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _watermarkController,
              decoration: InputDecoration(
                hintText: 'e.g. CONFIDENTIAL, DRAFT',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Header & Footer
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Header Text', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _headerController,
                        decoration: InputDecoration(
                          hintText: 'Top header',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Footer Text', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _footerController,
                        decoration: InputDecoration(
                          hintText: 'Bottom footer',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Page numbers toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include Page Numbers', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Display "Page X of Y" at the bottom right'),
              value: _includePageNumbers,
              onChanged: (val) => setState(() => _includePageNumbers = val),
            ),
            const SizedBox(height: 8),

            // Password Security
            const Text('Password Protection (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _userPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Leave empty for no password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton(
              onPressed: _applyChanges,
              child: const Text('Apply & Persist Page Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
