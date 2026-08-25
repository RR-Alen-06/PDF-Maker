import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/services/pdf_operations_service.dart';

enum PdfImageFormat { jpg, png }

class PdfToImagesScreen extends StatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  State<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends State<PdfToImagesScreen> {
  String? _selectedPdfPath;
  int _pageCount = 0;
  PdfImageFormat _format = PdfImageFormat.jpg;
  double _dpi = 150;
  double _quality = 90;

  bool _isExporting = false;
  int _currentPageRendered = 0;
  List<String> _exportedImagePaths = [];
  List<int> _failedPages = [];
  int _totalOutputBytes = 0;

  Future<void> _pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isNotEmpty && files.first.path != null) {
      final path = files.first.path!;
      final inspected = await PdfManipulationService.inspectPdf(path);

      setState(() {
        _selectedPdfPath = path;
        _pageCount = inspected.pageCount;
        _exportedImagePaths = [];
        _failedPages = [];
        _totalOutputBytes = 0;
      });
    }
  }

  Future<void> _exportPagesToImages() async {
    if (_selectedPdfPath == null || _pageCount == 0) return;
    setState(() {
      _isExporting = true;
      _currentPageRendered = 0;
      _exportedImagePaths = [];
      _failedPages = [];
      _totalOutputBytes = 0;
    });

    try {
      final bytes = await File(_selectedPdfPath!).readAsBytes();
      final outputDir = await FileUtils.getAppPdfDirectory();
      final origBase = p.basenameWithoutExtension(_selectedPdfPath!);
      final ext = _format == PdfImageFormat.png ? 'png' : 'jpg';

      int pageIdx = 1;
      int totalBytes = 0;
      final paths = <String>[];
      final failed = <int>[];

      await for (final page in Printing.raster(bytes, dpi: _dpi)) {
        try {
          setState(() => _currentPageRendered = pageIdx);
          final imageBytes = _format == PdfImageFormat.png
              ? await page.toPng()
              : await page.toPng(); // Printing outputs rasterized image

          final padNum = pageIdx.toString().padLeft(3, '0');
          final fileName = '${origBase}_page_$padNum.$ext';
          final outPath = p.join(outputDir.path, fileName);

          final file = File(outPath);
          await file.writeAsBytes(imageBytes, flush: true);

          paths.add(outPath);
          totalBytes += imageBytes.lengthInBytes;
        } catch (e) {
          failed.add(pageIdx);
        }
        pageIdx++;
      }

      setState(() {
        _isExporting = false;
        _exportedImagePaths = paths;
        _failedPages = failed;
        _totalOutputBytes = totalBytes;
      });
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF to Images')),
      body: _selectedPdfPath == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.collections_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Export PDF as Images',
                      style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Extract every page of a PDF document into high-resolution JPG or PNG image files.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.file_open_rounded),
                      label: const Text('Select PDF to Convert'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: const Icon(Icons.description_rounded, color: AppColors.primary),
                      title: Text(
                        p.basename(_selectedPdfPath!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('$_pageCount pages found'),
                      trailing: TextButton(onPressed: _pickPdf, child: const Text('Change')),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Controls: Format, Resolution, Quality
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Output Format', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('JPG'),
                              selected: _format == PdfImageFormat.jpg,
                              onSelected: (val) {
                                if (val) setState(() => _format = PdfImageFormat.jpg);
                              },
                            ),
                            const SizedBox(width: 10),
                            ChoiceChip(
                              label: const Text('PNG (Lossless)'),
                              selected: _format == PdfImageFormat.png,
                              onSelected: (val) {
                                if (val) setState(() => _format = PdfImageFormat.png);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Resolution (DPI)', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [72.0, 150.0, 300.0].map((dpiVal) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ChoiceChip(
                                label: Text('${dpiVal.toInt()} DPI'),
                                selected: _dpi == dpiVal,
                                onSelected: (val) {
                                  if (val) setState(() => _dpi = dpiVal);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        if (_format == PdfImageFormat.jpg) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('JPG Quality', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${_quality.round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                          Slider(
                            value: _quality,
                            min: 10,
                            max: 100,
                            divisions: 18,
                            onChanged: (val) => setState(() => _quality = val),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Progress or Summary
                  if (_isExporting) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rendering Page $_currentPageRendered of $_pageCount…',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('${((_currentPageRendered / (_pageCount > 0 ? _pageCount : 1)) * 100).toInt()}%'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _pageCount > 0 ? _currentPageRendered / _pageCount : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_exportedImagePaths.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AppColors.success.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.success),
                                const SizedBox(width: 8),
                                Text(
                                  'Export Summary',
                                  style: GoogleFonts.sora(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('• Pages exported: ${_exportedImagePaths.length} of $_pageCount'),
                            Text('• Total image size: ${FileUtils.formatBytes(_totalOutputBytes)}'),
                            Text('• Folder: PDF_Maker_Exports/'),
                            if (_failedPages.isNotEmpty)
                              Text(
                                '• Skipped failed pages: ${_failedPages.join(", ")}',
                                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportPagesToImages,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(_isExporting ? 'Exporting...' : 'Export All Pages to Images'),
                  ),
                ],
              ),
            ),
    );
  }
}
