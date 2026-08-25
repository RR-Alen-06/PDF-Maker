import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
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
  int _originalSizeBytes = 0;
  int _pageCount = 1;
  bool _hasSelectableText = false;
  CompressedPdfResult? _result;
  double _quality = 65.0;
  bool _isCompressing = false;
  int _estimatedOutputSize = 0;
  String? _compressionStatusMessage;

  Future<void> _pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isNotEmpty && files.first.path != null) {
      final path = files.first.path!;
      final file = File(path);
      final bytes = await file.readAsBytes();
      final textDetected = await PdfCompressorService.detectSelectableText(bytes);
      final pages = await PdfCompressorService.getPageCount(bytes);

      setState(() {
        _selectedPdfPath = path;
        _originalSizeBytes = bytes.lengthInBytes;
        _pageCount = pages;
        _hasSelectableText = textDetected;
        _result = null;
        _compressionStatusMessage = null;
        _estimatedOutputSize = (_originalSizeBytes * (_quality / 100.0) * 0.75).round();
      });

      if (_hasSelectableText) {
        _showTextWarningDialog();
      } else {
        _runCompression();
      }
    }
  }

  void _showTextWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.tertiary, size: 28),
            const SizedBox(width: 8),
            Text(
              'Selectable Text Found',
              style: GoogleFonts.sora(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: const Text(
          'This PDF contains selectable text. Compression will flatten it into images, making text non-selectable. Proceed?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runCompression();
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  void _onQualityChanged(double val) {
    setState(() {
      _quality = val;
      _estimatedOutputSize = (_originalSizeBytes * (_quality / 100.0) * 0.75).round();
    });
  }

  Future<void> _runCompression() async {
    if (_selectedPdfPath == null) return;
    setState(() {
      _isCompressing = true;
      _compressionStatusMessage = null;
    });

    try {
      final res = await PdfCompressorService.compressPdf(
        pdfPath: _selectedPdfPath!,
        imageQuality: _quality.round(),
      );

      // Acceptance Criteria: If compressed file is larger than or equal to original, inform user and do not save
      if (res.compressedSizeBytes >= res.originalSizeBytes) {
        setState(() {
          _result = null;
          _isCompressing = false;
          _compressionStatusMessage =
              'The PDF could not be reduced further at this quality setting.';
        });
        return;
      }

      setState(() {
        _result = res;
        _isCompressing = false;
        _compressionStatusMessage = null;
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
    if (_result == null || _selectedPdfPath == null) return;
    try {
      final originalFileName = p.basename(_selectedPdfPath!);
      final baseName = p.basenameWithoutExtension(originalFileName);
      final finalFileName = '${baseName}_compressed.pdf';

      final file = await FileUtils.savePdfFile(
        bytes: _result!.compressedBytes,
        fileName: finalFileName,
      );

      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: finalFileName,
        filePath: file.path,
        fileSizeBytes: _result!.compressedSizeBytes,
        pageCount: _pageCount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as $finalFileName'),
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
                    Text(
                      'Compress Existing PDF',
                      style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick exactly one PDF to shrink its file size while maintaining visual clarity.',
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
                // Metadata & Quality Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.basename(_selectedPdfPath!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${FileUtils.formatBytes(_originalSizeBytes)} • $_pageCount ${_pageCount == 1 ? "page" : "pages"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _pickPdf,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Image Quality',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_quality.round()}% (Est. ~${FileUtils.formatBytes(_estimatedOutputSize)})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _quality,
                        min: 10,
                        max: 100,
                        divisions: 18,
                        onChanged: _onQualityChanged,
                        onChangeEnd: (_) => _runCompression(),
                      ),
                    ],
                  ),
                ),

                // Compression Results or Inability to Reduce Message
                if (_isCompressing)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Compressing PDF streams…'),
                        ],
                      ),
                    ),
                  )
                else if (_compressionStatusMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.tertiary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _compressionStatusMessage!,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_result != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                      label: const Text('Save as <name>_compressed.pdf'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
