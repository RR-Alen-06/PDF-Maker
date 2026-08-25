import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history_and_settings/services/history_storage_service.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';

class PdfPreviewScreen extends ConsumerStatefulWidget {
  final String? initialFileName;

  const PdfPreviewScreen({
    super.key,
    this.initialFileName,
  });

  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  bool _isSaving = false;
  File? _savedFile;
  final int _currentPageIndex = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    final pdfState = ref.read(photoToPdfProvider);
    final count = (pdfState.photos.length / pdfState.config.layout.photosPerPage).ceil();
    _totalPages = count > 0 ? count : 1;
  }

  void _showSaveNamingDialog() async {
    final pdfState = ref.read(photoToPdfProvider);
    final bytes = pdfState.generatedPdfBytes;
    if (bytes == null) return;

    final defaultName = await FileUtils.generateNextDefaultFileName();
    final initialNameWithoutExt = defaultName.replaceAll('.pdf', '');

    if (!mounted) return;

    final controller = TextEditingController(text: initialNameWithoutExt);
    String? validationError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Save PDF Document',
                style: GoogleFonts.sora(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter a file name for the generated document:',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'File Name',
                      suffixText: '.pdf',
                      errorText: validationError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      // Silently sanitize invalid characters \ / : * ? " < > |
                      final sanitized = FileUtils.sanitizeFileName(val);
                      if (sanitized != val) {
                        final selection = controller.selection;
                        controller.text = sanitized;
                        controller.selection = TextSelection.collapsed(
                          offset: selection.baseOffset.clamp(0, sanitized.length),
                        );
                      }
                      if (sanitized.trim().isNotEmpty && validationError != null) {
                        setDialogState(() => validationError = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final trimmed = controller.text.trim();
                    if (trimmed.isEmpty) {
                      setDialogState(() {
                        validationError = 'File name cannot be empty';
                      });
                      return;
                    }

                    Navigator.pop(dialogCtx);
                    await _executeSaveFile(trimmed, bytes);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeSaveFile(String baseName, List<int> bytes) async {
    setState(() => _isSaving = true);
    final pdfState = ref.read(photoToPdfProvider);

    try {
      final file = await FileUtils.savePdfFile(
        bytes: bytes,
        fileName: '$baseName.pdf',
      );

      // Record to persistent local history
      final historyService = HistoryStorageService();
      await historyService.addHistoryItem(
        title: '$baseName.pdf',
        filePath: file.path,
        fileSizeBytes: bytes.length,
        pageCount: (pdfState.photos.length / pdfState.config.layout.photosPerPage).ceil(),
      );

      setState(() {
        _savedFile = file;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${file.path.split(Platform.pathSeparator).last}'),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Arrangement',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Page counter badge
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Page $_currentPageIndex of $_totalPages',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
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
                // Interactive Zoomable PDF Viewer with 4x maximum zoom level
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    clipBehavior: Clip.none,
                    child: PdfPreview(
                      build: (format) => bytes,
                      useActions: true,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      loadingWidget: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Rendering preview…', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Edit Layout'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(130, 50)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _showSaveNamingDialog,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_alt_rounded),
                  label: Text(_savedFile != null ? 'Save Again' : 'Save PDF'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 50),
                    backgroundColor: _savedFile != null ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
