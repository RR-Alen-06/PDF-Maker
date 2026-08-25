import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/overlay_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';

class OverlaySettingsModal extends StatefulWidget {
  final PdfExportConfig initialConfig;
  final ValueChanged<PdfExportConfig> onSave;

  const OverlaySettingsModal({
    super.key,
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<OverlaySettingsModal> createState() => _OverlaySettingsModalState();
}

class _OverlaySettingsModalState extends State<OverlaySettingsModal> {
  late bool _enablePageNumbers;
  late PageNumberFormatPreset _pageNumberFormat;
  late OverlayGridPosition _pageNumberPosition;
  late double _pageNumberFontSize;

  late bool _enableDateStamp;
  late DateStampSource _dateStampSource;
  late DateTime _customDate;
  late DateStampFormatPreset _dateStampFormat;
  late OverlayGridPosition _dateStampPosition;
  late double _dateStampFontSize;

  late bool _enableWatermark;
  late TextEditingController _watermarkController;
  late double _watermarkOpacity;
  late double _watermarkRotationAngle;
  late OverlayGridPosition _watermarkPosition;
  late double _watermarkFontSize;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _enablePageNumbers = c.enablePageNumbers;
    _pageNumberFormat = c.pageNumberFormatPreset;
    _pageNumberPosition = c.pageNumberPosition;
    _pageNumberFontSize = c.pageNumberFontSize;

    _enableDateStamp = c.enableDateStamp;
    _dateStampSource = c.dateStampSource;
    _customDate = c.customDate ?? DateTime.now();
    _dateStampFormat = c.dateStampFormatPreset;
    _dateStampPosition = c.dateStampPosition;
    _dateStampFontSize = c.dateStampFontSize;

    _enableWatermark = c.enableWatermark;
    _watermarkController = TextEditingController(text: c.watermarkText ?? 'CONFIDENTIAL');
    _watermarkOpacity = c.watermarkOpacity;
    _watermarkRotationAngle = c.watermarkRotationAngle;
    _watermarkPosition = c.watermarkPosition;
    _watermarkFontSize = c.watermarkFontSize;
  }

  @override
  void dispose() {
    _watermarkController.dispose();
    super.dispose();
  }

  bool get _hasConflict =>
      _enablePageNumbers &&
      _enableDateStamp &&
      _pageNumberPosition == _dateStampPosition;

  void _notifyChange() {
    final updated = widget.initialConfig.copyWith(
      enablePageNumbers: _enablePageNumbers,
      pageNumberFormatPreset: _pageNumberFormat,
      pageNumberPosition: _pageNumberPosition,
      pageNumberFontSize: _pageNumberFontSize,
      enableDateStamp: _enableDateStamp,
      dateStampSource: _dateStampSource,
      customDate: _customDate,
      dateStampFormatPreset: _dateStampFormat,
      dateStampPosition: _dateStampPosition,
      dateStampFontSize: _dateStampFontSize,
      enableWatermark: _enableWatermark,
      watermarkText: _watermarkController.text.trim().isEmpty ? null : _watermarkController.text.trim(),
      watermarkOpacity: _watermarkOpacity,
      watermarkRotationAngle: _watermarkRotationAngle,
      watermarkPosition: _watermarkPosition,
      watermarkFontSize: _watermarkFontSize,
    );
    widget.onSave(updated);
  }

  Widget _buildPositionGrid({
    required OverlayGridPosition currentPosition,
    required ValueChanged<OverlayGridPosition> onSelected,
    required bool hasConflict,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: hasConflict
            ? AppColors.error.withValues(alpha: 0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasConflict ? AppColors.error : Colors.grey.withValues(alpha: 0.3),
          width: hasConflict ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          for (int r = 0; r < 3; r++)
            Row(
              children: [
                for (int c = 0; c < 3; c++) ...[
                  Expanded(
                    child: _buildGridCell(
                      OverlayGridPosition.values[r * 3 + c],
                      currentPosition,
                      onSelected,
                      hasConflict,
                    ),
                  ),
                  if (c < 2) const SizedBox(width: 6),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGridCell(
    OverlayGridPosition pos,
    OverlayGridPosition currentPos,
    ValueChanged<OverlayGridPosition> onSelected,
    bool hasConflict,
  ) {
    final isSelected = pos == currentPos;
    return InkWell(
      onTap: () {
        onSelected(pos);
        setState(() {});
        _notifyChange();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? (hasConflict ? AppColors.error : AppColors.primary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (hasConflict ? AppColors.error : AppColors.primary)
                : Colors.grey.withValues(alpha: 0.25),
          ),
        ),
        child: Center(
          child: Text(
            pos.label.split(' ').map((w) => w[0]).join(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreviewBox() {
    final date = _dateStampSource == DateStampSource.custom ? _customDate : DateTime.now();

    return Container(
      height: 180,
      width: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          // Dummy photo background
          Center(
            child: Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade300),
          ),

          // Watermark live preview
          if (_enableWatermark && _watermarkController.text.isNotEmpty)
            Align(
              alignment: _getAlignmentFromPos(_watermarkPosition),
              child: Transform.rotate(
                angle: (_watermarkRotationAngle * 3.141592653589793) / 180,
                child: Text(
                  _watermarkController.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (_watermarkFontSize * 0.35).clamp(8.0, 16.0),
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withValues(alpha: _watermarkOpacity),
                  ),
                ),
              ),
            ),

          // Date stamp live preview
          if (_enableDateStamp)
            Align(
              alignment: _getAlignmentFromPos(_dateStampPosition),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  _dateStampFormat.format(date),
                  style: TextStyle(
                    fontSize: (_dateStampFontSize * 0.6).clamp(6.0, 10.0),
                    color: _hasConflict ? Colors.red : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // Page Number live preview
          if (_enablePageNumbers)
            Align(
              alignment: _getAlignmentFromPos(_pageNumberPosition),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  _pageNumberFormat.format(1, 5),
                  style: TextStyle(
                    fontSize: (_pageNumberFontSize * 0.6).clamp(6.0, 10.0),
                    color: _hasConflict ? Colors.red : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Alignment _getAlignmentFromPos(OverlayGridPosition pos) {
    switch (pos) {
      case OverlayGridPosition.topLeft:
        return Alignment.topLeft;
      case OverlayGridPosition.topCenter:
        return Alignment.topCenter;
      case OverlayGridPosition.topRight:
        return Alignment.topRight;
      case OverlayGridPosition.middleLeft:
        return Alignment.centerLeft;
      case OverlayGridPosition.middleCenter:
        return Alignment.center;
      case OverlayGridPosition.middleRight:
        return Alignment.centerRight;
      case OverlayGridPosition.bottomLeft:
        return Alignment.bottomLeft;
      case OverlayGridPosition.bottomCenter:
        return Alignment.bottomCenter;
      case OverlayGridPosition.bottomRight:
        return Alignment.bottomRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
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
                  'Overlay Settings',
                  style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // Live Preview Card
            Center(
              child: Column(
                children: [
                  const Text('Live First Page Preview', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  _buildLivePreviewBox(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Warning Banner for overlapping positions
            if (_hasConflict) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Overlapping positions — items may be obscured',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Section 1: Page Numbers
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Page Numbers', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Render page counts on each sheet'),
              value: _enablePageNumbers,
              onChanged: (val) {
                setState(() => _enablePageNumbers = val);
                _notifyChange();
              },
            ),
            if (_enablePageNumbers) ...[
              const SizedBox(height: 6),
              DropdownButtonFormField<PageNumberFormatPreset>(
                initialValue: _pageNumberFormat,
                decoration: InputDecoration(
                  labelText: 'Format',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: PageNumberFormatPreset.values.map((f) {
                  return DropdownMenuItem(value: f, child: Text(f.label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _pageNumberFormat = val);
                    _notifyChange();
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Font Size (8–36 pt)', style: TextStyle(fontSize: 13)),
                  Text('${_pageNumberFontSize.round()} pt', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _pageNumberFontSize,
                min: 8,
                max: 36,
                divisions: 14,
                onChanged: (val) {
                  setState(() => _pageNumberFontSize = val);
                  _notifyChange();
                },
              ),
              const Text('Grid Position', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _buildPositionGrid(
                currentPosition: _pageNumberPosition,
                hasConflict: _hasConflict,
                onSelected: (pos) => _pageNumberPosition = pos,
              ),
              const SizedBox(height: 16),
            ],

            const Divider(),

            // Section 2: Date Stamp
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date Stamp', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Include export date on document'),
              value: _enableDateStamp,
              onChanged: (val) {
                setState(() => _enableDateStamp = val);
                _notifyChange();
              },
            ),
            if (_enableDateStamp) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<DateStampSource>(
                      initialValue: _dateStampSource,
                      decoration: InputDecoration(
                        labelText: 'Source',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: DateStampSource.values.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s.label.split(' ').first));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _dateStampSource = val);
                          _notifyChange();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<DateStampFormatPreset>(
                      initialValue: _dateStampFormat,
                      decoration: InputDecoration(
                        labelText: 'Format',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: DateStampFormatPreset.values.map((f) {
                        return DropdownMenuItem(value: f, child: Text(f.label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _dateStampFormat = val);
                          _notifyChange();
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_dateStampSource == DateStampSource.custom) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _customDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _customDate = picked);
                      _notifyChange();
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text('Pick Date: ${_customDate.toIso8601String().split('T').first}'),
                ),
              ],
              const SizedBox(height: 10),
              const Text('Grid Position', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _buildPositionGrid(
                currentPosition: _dateStampPosition,
                hasConflict: _hasConflict,
                onSelected: (pos) => _dateStampPosition = pos,
              ),
              const SizedBox(height: 16),
            ],

            const Divider(),

            // Section 3: Watermark Text
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Watermark Text', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Add branded diagonal or positioned text'),
              value: _enableWatermark,
              onChanged: (val) {
                setState(() => _enableWatermark = val);
                _notifyChange();
              },
            ),
            if (_enableWatermark) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _watermarkController,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Watermark Text (Max 100 chars)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) {
                  setState(() {});
                  _notifyChange();
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Opacity (10%–100%)', style: TextStyle(fontSize: 13)),
                  Text('${(_watermarkOpacity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _watermarkOpacity,
                min: 0.1,
                max: 1.0,
                divisions: 18,
                onChanged: (val) {
                  setState(() => _watermarkOpacity = val);
                  _notifyChange();
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rotation Angle (0°–360°)', style: TextStyle(fontSize: 13)),
                  Text('${_watermarkRotationAngle.round()}°', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _watermarkRotationAngle,
                min: 0,
                max: 360,
                divisions: 360,
                onChanged: (val) {
                  setState(() => _watermarkRotationAngle = val);
                  _notifyChange();
                },
              ),
              const Text('Grid Position', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _buildPositionGrid(
                currentPosition: _watermarkPosition,
                hasConflict: false,
                onSelected: (pos) => _watermarkPosition = pos,
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _notifyChange();
                Navigator.pop(context);
              },
              child: const Text('Apply Overlay Settings'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
