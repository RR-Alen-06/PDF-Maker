import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history_and_settings/services/history_storage_service.dart';
import 'package:pdf_maker/features/tools/pdf_compressor/services/pdf_compressor_service.dart';

class PdfCompressorScreen extends StatefulWidget {
  const PdfCompressorScreen({super.key});

  @override
  State<PdfCompressorScreen> createState() => _PdfCompressorScreenState();
}

class _PdfCompressorScreenState extends State<PdfCompressorScreen> {
  String? _selectedPdfPath;
  CompressedPdfResult? _result;
  double _quality = 65.0;
  bool _isCompressing = false;

  Future<void> _pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isNotEmpty && files.first.path != null) {
      setState(() {
        _selectedPdfPath = files.first.path;
        _result = null;
      });
      _runCompression();
    }
  }

  Future<void> _runCompression() async {
    if (_selectedPdfPath == null) return;
    setState(() => _isCompressing = true);

    try {
      final res = await PdfCompressorService.compressPdf(
        pdfPath: _selectedPdfPath!,
        imageQuality: _quality.round(),
      );

      setState(() {
        _result = res;
        _isCompressing = false;
      });
    } catch (e) {
      setState(() => _isCompressing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to compress PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveCompressedPdf() async {
    if (_result == null) return;
    try {
      final fileName = 'Compressed_${_result!.outputPath.split(Platform.pathSeparator).last}';
      final file = await FileUtils.savePdfFile(
        bytes: _result!.compressedBytes,
        fileName: fileName,
      );

      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: fileName,
        filePath: file.path,
        fileSizeBytes: _result!.compressedSizeBytes,
        pageCount: 1,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path.split(Platform.pathSeparator).last}'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
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
        title: const Text('PDF Compressor'),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Compressed PDF',
              onPressed: () => FileUtils.sharePdf(_result!.outputPath),
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
                        Icons.picture_as_pdf_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Compress Existing PDF',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick any PDF on your device to shrink its file size while maintaining visual quality.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.file_open_rounded),
                      label: const Text('Select PDF File'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // File & Quality Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_rounded, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedPdfPath!.split(Platform.pathSeparator).last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            onPressed: _pickPdf,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quality Level',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_quality.round()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _quality,
                        min: 20,
                        max: 95,
                        divisions: 15,
                        onChanged: (val) => setState(() => _quality = val),
                        onChangeEnd: (_) => _runCompression(),
                      ),
                    ],
                  ),
                ),

                // Compression Results Card
                if (_isCompressing)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Compressing PDF streams...'),
                        ],
                      ),
                    ),
                  )
                else if (_result != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('Original Size', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                      FileUtils.formatBytes(_result!.originalSizeBytes),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                                Column(
                                  children: [
                                    const Text('Compressed Size', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                      FileUtils.formatBytes(_result!.compressedSizeBytes),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.trending_down_rounded, color: AppColors.success, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Reduced by ${_result!.reductionPercentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: _result == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => FileUtils.openPdf(_result!.outputPath),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(120, 52)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveCompressedPdf,
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('Save PDF'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
