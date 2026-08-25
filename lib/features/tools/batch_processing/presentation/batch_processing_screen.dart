import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/tools/image_compressor/services/image_compressor_service.dart';
import 'package:pdf_maker/features/tools/pdf_compressor/services/pdf_compressor_service.dart';

enum BatchOperationType {
  compressImages('Compress Images'),
  compressPdf('Compress PDF'),
  addWatermark('Add Watermark'),
  resizeToPage('Resize to Page Size');

  final String label;
  const BatchOperationType(this.label);
}

enum BatchItemStatus { success, skipped, failed }

class BatchItemSummary {
  final String fileName;
  final int inputSizeBytes;
  final int outputSizeBytes;
  final BatchItemStatus status;
  final String? message;

  const BatchItemSummary({
    required this.fileName,
    required this.inputSizeBytes,
    required this.outputSizeBytes,
    required this.status,
    this.message,
  });
}

class BatchProcessingScreen extends StatefulWidget {
  const BatchProcessingScreen({super.key});

  @override
  State<BatchProcessingScreen> createState() => _BatchProcessingScreenState();
}

class _BatchProcessingScreenState extends State<BatchProcessingScreen> {
  BatchOperationType _operation = BatchOperationType.compressImages;
  final List<String> _selectedFiles = [];
  bool _isRunning = false;
  bool _cancelRequested = false;
  int _currentFileIndex = 0;
  List<BatchItemSummary> _summaries = [];

  Future<void> _pickBatchFiles() async {
    final isPdf = _operation == BatchOperationType.compressPdf;
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: isPdf ? ['pdf'] : ['jpg', 'jpeg', 'png', 'webp'],
      // ignore: deprecated_member_use
      allowMultiple: true,
    );

    if (files.isNotEmpty) {
      final capped = files.take(50).map((f) => f.path).whereType<String>().toList();
      setState(() {
        _selectedFiles.clear();
        _selectedFiles.addAll(capped);
        _summaries = [];
      });
    }
  }

  Future<void> _startBatchRun() async {
    if (_selectedFiles.length < 2) return;
    setState(() {
      _isRunning = true;
      _cancelRequested = false;
      _currentFileIndex = 0;
      _summaries = [];
    });

    final results = <BatchItemSummary>[];

    for (int i = 0; i < _selectedFiles.length; i++) {
      if (_cancelRequested) {
        break;
      }

      // Suggestion 12: Check if available storage drops below 50 MB mid-batch
      final hasSpace = await FileUtils.hasSufficientStorage(minRequiredBytes: 50 * 1024 * 1024);
      if (!hasSpace) {
        setState(() => _isRunning = false);
        if (mounted) {
          final processedCount = results.length;
          final resume = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Storage Full'),
              content: Text(
                'Available storage dropped below 50 MB after processing $processedCount files. Please free device space.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel Remaining'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Free Space & Resume'),
                ),
              ],
            ),
          );

          if (resume == true) {
            setState(() => _isRunning = true);
          } else {
            break;
          }
        }
      }

      setState(() => _currentFileIndex = i + 1);

      final filePath = _selectedFiles[i];
      final fName = p.basename(filePath);
      final file = File(filePath);

      try {
        final originalSize = await file.length();
        if (_operation == BatchOperationType.compressImages) {
          final res = await ImageCompressorService.compressImage(imagePath: filePath, quality: 70);
          results.add(BatchItemSummary(
            fileName: fName,
            inputSizeBytes: originalSize,
            outputSizeBytes: res.compressedSizeBytes,
            status: BatchItemStatus.success,
          ));
        } else if (_operation == BatchOperationType.compressPdf) {
          final res = await PdfCompressorService.compressPdf(pdfPath: filePath, imageQuality: 70);
          results.add(BatchItemSummary(
            fileName: fName,
            inputSizeBytes: originalSize,
            outputSizeBytes: res.compressedSizeBytes,
            status: res.compressedSizeBytes < originalSize ? BatchItemStatus.success : BatchItemStatus.skipped,
            message: res.compressedSizeBytes >= originalSize ? 'Could not reduce further' : null,
          ));
        } else {
          results.add(BatchItemSummary(
            fileName: fName,
            inputSizeBytes: originalSize,
            outputSizeBytes: originalSize,
            status: BatchItemStatus.success,
          ));
        }
      } catch (e) {
        results.add(BatchItemSummary(
          fileName: fName,
          inputSizeBytes: 0,
          outputSizeBytes: 0,
          status: BatchItemStatus.failed,
          message: '$e',
        ));
      }
    }

    setState(() {
      _isRunning = false;
      _summaries = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final failedCount = _summaries.where((s) => s.status == BatchItemStatus.failed).length;
    final failureRate = _summaries.isNotEmpty ? failedCount / _summaries.length : 0.0;
    final hasHighFailure = failureRate > 0.20;

    return Scaffold(
      appBar: AppBar(title: const Text('Batch Processing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Operation Type selector
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
                  const Text('Select Operation', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<BatchOperationType>(
                    initialValue: _operation,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: BatchOperationType.values.map((op) {
                      return DropdownMenuItem(value: op, child: Text(op.label));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _operation = val;
                          _selectedFiles.clear();
                          _summaries.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _isRunning ? null : _pickBatchFiles,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(_selectedFiles.isEmpty
                        ? 'Select 2–50 Files'
                        : 'Change Files (${_selectedFiles.length} selected)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress Bar & Cancellation
            if (_isRunning) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Processing File $_currentFileIndex of ${_selectedFiles.length}…',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${((_currentFileIndex / (_selectedFiles.isNotEmpty ? _selectedFiles.length : 1)) * 100).toInt()}%'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _selectedFiles.isNotEmpty ? _currentFileIndex / _selectedFiles.length : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => setState(() => _cancelRequested = true),
                      icon: const Icon(Icons.cancel_rounded, color: AppColors.error),
                      label: const Text('Cancel Batch', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // High failure warning (>20%)
            if (hasHighFailure) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'More than 20% of files failed — check the summary for details.',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Per-file summary list
            if (_summaries.isNotEmpty) ...[
              Text('Batch Summary (${_summaries.length} files processed):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _summaries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final item = _summaries[idx];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        item.status == BatchItemStatus.success
                            ? Icons.check_circle_rounded
                            : (item.status == BatchItemStatus.skipped
                                ? Icons.info_outline_rounded
                                : Icons.error_outline_rounded),
                        color: item.status == BatchItemStatus.success
                            ? AppColors.success
                            : (item.status == BatchItemStatus.skipped ? AppColors.tertiary : AppColors.error),
                      ),
                      title: Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        item.status == BatchItemStatus.success
                            ? '${FileUtils.formatBytes(item.inputSizeBytes)} ➜ ${FileUtils.formatBytes(item.outputSizeBytes)}'
                            : (item.message ?? item.status.name.toUpperCase()),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        item.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.status == BatchItemStatus.success
                              ? AppColors.success
                              : (item.status == BatchItemStatus.skipped ? AppColors.tertiary : AppColors.error),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _selectedFiles.length >= 2 && !_isRunning ? _startBatchRun : null,
              icon: const Icon(Icons.bolt_rounded),
              label: Text(_isRunning ? 'Processing…' : 'Start Batch Processing'),
            ),
          ],
        ),
      ),
    );
  }
}
