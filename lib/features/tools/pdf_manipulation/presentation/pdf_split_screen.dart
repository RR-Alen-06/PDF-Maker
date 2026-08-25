import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history/services/history_storage_service.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/services/pdf_operations_service.dart';

class PdfSplitScreen extends StatefulWidget {
  const PdfSplitScreen({super.key});

  @override
  State<PdfSplitScreen> createState() => _PdfSplitScreenState();
}

class _PdfSplitScreenState extends State<PdfSplitScreen> {
  String? _selectedPdfPath;
  int _totalPageCount = 0;
  int _fromPage = 1;
  int _toPage = 1;
  bool _isSplitting = false;
  File? _savedFile;

  Future<void> _pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isNotEmpty && files.first.path != null) {
      final path = files.first.path!;
      final bytes = await File(path).readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();

      setState(() {
        _selectedPdfPath = path;
        _totalPageCount = count;
        _fromPage = 1;
        _toPage = count > 0 ? count : 1;
        _savedFile = null;
      });
    }
  }

  bool get _isSinglePage => _totalPageCount <= 1;
  bool get _hasInvalidRange => _fromPage > _toPage || _isSinglePage;

  Future<void> _splitPdf() async {
    if (_selectedPdfPath == null || _hasInvalidRange) return;

    final pages = <int>[];
    for (int i = _fromPage; i <= _toPage; i++) {
      if (i >= 1 && i <= _totalPageCount) {
        pages.add(i);
      }
    }

    if (pages.isEmpty) return;

    setState(() => _isSplitting = true);
    try {
      final bytes = await PdfManipulationService.splitPdf(
        pdfPath: _selectedPdfPath!,
        pageNumbers: pages,
      );

      final originalName = p.basenameWithoutExtension(_selectedPdfPath!);
      final fileName = '${originalName}_p$_fromPage-p$_toPage.pdf';
      final file = await FileUtils.savePdfFile(bytes: bytes, fileName: fileName);

      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: fileName,
        filePath: file.path,
        fileSizeBytes: bytes.lengthInBytes,
        pageCount: pages.length,
      );

      setState(() {
        _savedFile = file;
        _isSplitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted $fileName (${pages.length} pages)'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => FileUtils.openPdf(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSplitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
        actions: [
          if (_savedFile != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Extracted PDF',
              onPressed: () => FileUtils.sharePdf(_savedFile!.path),
            ),
        ],
      ),
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
                        Icons.call_split_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Extract Specific Pages',
                      style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a PDF and choose a page range (From page / To page) to extract into a new document.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.file_open_rounded),
                      label: const Text('Select PDF to Split'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
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
                      subtitle: Text('Total pages: $_totalPageCount'),
                      trailing: TextButton(
                        onPressed: _pickPdf,
                        child: const Text('Change'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Range Selectors (From page / To page, each 1 to N)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _hasInvalidRange
                            ? AppColors.error
                            : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Page Range Selector',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // From Page
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('From Page', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    initialValue: _fromPage,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    items: List.generate(_totalPageCount, (i) => i + 1).map((pageVal) {
                                      return DropdownMenuItem(value: pageVal, child: Text('Page $pageVal'));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _fromPage = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            // To Page
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('To Page', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    initialValue: _toPage,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    items: List.generate(_totalPageCount, (i) => i + 1).map((pageVal) {
                                      return DropdownMenuItem(value: pageVal, child: Text('Page $pageVal'));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _toPage = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Inline validation message
                        if (_isSinglePage) ...[
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: AppColors.tertiary, size: 16),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Splitting requires a PDF with at least 2 pages.',
                                  style: TextStyle(
                                    color: AppColors.tertiary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (_fromPage > _toPage) ...[
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Start page must be ≤ end page',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text(
                            'Will extract ${_toPage - _fromPage + 1} page(s) into: ${p.basenameWithoutExtension(_selectedPdfPath!)}_p$_fromPage-p$_toPage.pdf',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isSplitting || _hasInvalidRange ? null : _splitPdf,
                    icon: _isSplitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.call_split_rounded),
                    label: Text(_isSplitting ? 'Extracting...' : 'Extract Pages into New PDF'),
                  ),
                ],
              ),
            ),
    );
  }
}
