import 'package:flutter/material.dart';
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
  late PageOrientation _orientation;
  late PageMarginPreset _marginPreset;
  late ImageQualityPreset _qualityPreset;
  late BoxFit _imageFit;
  late bool _includePageNumbers;
  late TextEditingController _watermarkController;
  late TextEditingController _headerController;
  late TextEditingController _footerController;
  late TextEditingController _userPasswordController;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _pageSize = c.pageSizePreset;
    _orientation = c.orientation;
    _marginPreset = c.marginPreset;
    _qualityPreset = c.qualityPreset;
    _imageFit = c.imageFit;
    _includePageNumbers = c.includePageNumbers;
    _watermarkController = TextEditingController(text: c.watermarkText ?? '');
    _headerController = TextEditingController(text: c.headerText ?? '');
    _footerController = TextEditingController(text: c.footerText ?? '');
    _userPasswordController = TextEditingController(text: c.userPassword ?? '');
  }

  @override
  void dispose() {
    _watermarkController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    _userPasswordController.dispose();
    super.dispose();
  }

  void _applyChanges() {
    final updated = widget.initialConfig.copyWith(
      pageSizePreset: _pageSize,
      orientation: _orientation,
      marginPreset: _marginPreset,
      qualityPreset: _qualityPreset,
      imageFit: _imageFit,
      includePageNumbers: _includePageNumbers,
      watermarkText: _watermarkController.text.trim().isEmpty ? null : _watermarkController.text.trim(),
      headerText: _headerController.text.trim().isEmpty ? null : _headerController.text.trim(),
      footerText: _footerController.text.trim().isEmpty ? null : _footerController.text.trim(),
      userPassword: _userPasswordController.text.trim().isEmpty ? null : _userPasswordController.text.trim(),
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
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
                const Text(
                  'Page & Document Setup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // Page Size
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
            const SizedBox(height: 16),

            // Orientation & Margin
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Margins', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<PageMarginPreset>(
                        initialValue: _marginPreset,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: PageMarginPreset.values.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m.label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _marginPreset = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Watermark
            const Text('Watermark Text', style: TextStyle(fontWeight: FontWeight.w600)),
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
              child: const Text('Apply Page Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
