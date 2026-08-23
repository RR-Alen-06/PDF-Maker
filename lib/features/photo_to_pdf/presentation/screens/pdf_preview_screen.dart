import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history_and_settings/services/history_storage_service.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';

class PdfPreviewScreen extends ConsumerStatefulWidget {
  final String suggestedFileName;

  const PdfPreviewScreen({
    super.key,
    required this.suggestedFileName,
  });

  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  late TextEditingController _fileNameController;
  bool _isSaving = false;
  File? _savedFile;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController(
      text: widget.suggestedFileName.replaceAll('.pdf', ''),
    );
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final pdfState = ref.read(photoToPdfProvider);
    final bytes = pdfState.generatedPdfBytes;
    if (bytes == null) return;

    setState(() => _isSaving = true);
    try {
      final name = _fileNameController.text.trim().isEmpty
          ? 'Document'
          : _fileNameController.text.trim();
      final file = await FileUtils.savePdfFile(
        bytes: bytes,
        fileName: '$name.pdf',
      );

      // Record to persistent local history
      final historyService = HistoryStorageService();
      await historyService.addHistoryItem(
        title: '$name.pdf',
        filePath: file.path,
        fileSizeBytes: bytes.lengthInBytes,
        pageCount: (pdfState.photos.length / pdfState.config.layout.photosPerPage).ceil(),
      );

      setState(() {
        _savedFile = file;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved successfully: ${file.path.split(Platform.pathSeparator).last}'),
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
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pdfState = ref.watch(photoToPdfProvider);
    final bytes = pdfState.generatedPdfBytes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Preview'),
        actions: [
          if (_savedFile != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share PDF',
              onPressed: () => FileUtils.sharePdf(_savedFile!.path),
            ),
        ],
      ),
      body: bytes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Action & File Name Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fileNameController,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'File Name',
                            suffixText: '.pdf',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_alt_rounded),
                        label: Text(_savedFile != null ? 'Saved' : 'Save PDF'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(120, 48),
                          backgroundColor: _savedFile != null ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Interactive PDF Viewer & Print Engine
                Expanded(
                  child: PdfPreview(
                    build: (format) => bytes,
                    useActions: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    loadingWidget: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            ),
    );
  }
}
