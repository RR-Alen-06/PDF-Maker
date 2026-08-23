import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history_and_settings/services/history_storage_service.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/services/pdf_manipulation_service.dart';

class PdfSplitScreen extends StatefulWidget {
  const PdfSplitScreen({super.key});

  @override
  State<PdfSplitScreen> createState() => _PdfSplitScreenState();
}

class _PdfSplitScreenState extends State<PdfSplitScreen> {
  String? _selectedPdfPath;
  int _totalPageCount = 0;
  final TextEditingController _rangeController = TextEditingController();
  bool _isSplitting = false;

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
        _rangeController.text = '1-$count';
      });
    }
  }

  List<int> _parsePageRange(String input, int maxPages) {
    final Set<int> pageSet = {};
    final segments = input.split(',');
    for (final seg in segments) {
      final trimmed = seg.trim();
      if (trimmed.contains('-')) {
        final parts = trimmed.split('-');
        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());
        if (start != null && end != null) {
          for (int i = start; i <= end; i++) {
            if (i >= 1 && i <= maxPages) pageSet.add(i);
          }
        }
      } else {
        final single = int.tryParse(trimmed);
        if (single != null && single >= 1 && single <= maxPages) {
          pageSet.add(single);
        }
      }
    }
    final sorted = pageSet.toList()..sort();
    return sorted;
  }

  Future<void> _splitPdf() async {
    if (_selectedPdfPath == null) return;
    final pages = _parsePageRange(_rangeController.text, _totalPageCount);
    if (pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify valid page numbers within range'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSplitting = true);
    try {
      final bytes = await PdfManipulationService.splitPdf(
        pdfPath: _selectedPdfPath!,
        pageNumbers: pages,
      );

      final fileName = FileUtils.generateDefaultFileName(prefix: 'Extracted_Pages');
      final file = await FileUtils.savePdfFile(bytes: bytes, fileName: fileName);

      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: fileName,
        filePath: file.path,
        fileSizeBytes: bytes.lengthInBytes,
        pageCount: pages.length,
      );

      setState(() => _isSplitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted ${pages.length} page(s) successfully!'),
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
      appBar: AppBar(title: const Text('Split PDF')),
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
                    const Text(
                      'Extract Specific Pages',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick a PDF and extract any page range (e.g. 1-3, 5, 8-10) into a new document.',
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
                    child: ListTile(
                      leading: const Icon(Icons.description_rounded, color: AppColors.primary),
                      title: Text(
                        _selectedPdfPath!.split(Platform.pathSeparator).last,
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
                  const Text(
                    'Page Range to Extract',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rangeController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 1-3, 5, 7',
                      helperText: 'Enter comma-separated page numbers or ranges (1 to $_totalPageCount)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isSplitting ? null : _splitPdf,
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
