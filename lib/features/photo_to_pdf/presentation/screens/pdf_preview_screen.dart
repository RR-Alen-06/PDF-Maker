import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history/services/history_storage_service.dart';
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
  int _currentPageIndex = 1;
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

      // Suggestion 35: In-App Review Prompt after 3rd PDF (throttled to 30 days)
      try {
        final prefs = await SharedPreferences.getInstance();
        final saveCount = (prefs.getInt('pdf_save_count') ?? 0) + 1;
        await prefs.setInt('pdf_save_count', saveCount);

        final lastPromptStr = prefs.getString('last_review_prompt_date');
        final lastPrompt = lastPromptStr != null ? DateTime.tryParse(lastPromptStr) : null;
        final shouldPrompt = saveCount >= 3 &&
            (lastPrompt == null || DateTime.now().difference(lastPrompt).inDays >= 30);

        if (shouldPrompt && mounted) {
          await prefs.setString('last_review_prompt_date', DateTime.now().toIso8601String());
          if (!mounted) return;
          // Show non-intrusive rate app dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Enjoying PDF Maker?'),
                ],
              ),
              content: const Text('Would you take a moment to rate us on the app store? It helps support ongoing development!'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not Now')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Rate App'),
                ),
              ],
            ),
          );
        }
      } catch (_) {}

      setState(() {
        _savedFile = file;
        _isSaving = false;
      });

      if (mounted) {
        _showSuccessShareOpenSheet(file);
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

  /// Displays post-save bottom sheet with "Share" and "Open" actions.
  /// When dismissed, navigates back to the Home screen.
  void _showSuccessShareOpenSheet(File file) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PDF Saved Successfully!',
                            style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            file.path.split(Platform.pathSeparator).last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await FileUtils.sharePdf(file.path);
                        },
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await FileUtils.openPdf(file.path);
                          if (result.type != ResultType.done && mounted) {
                            showDialog(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('Viewer Not Found'),
                                content: const Text('No PDF viewer found. Please install one from the store.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done • Return to Home'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      // When the user dismisses the bottom sheet, navigate to the Home screen
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  Widget _buildQualityChip(String label, ImageQualityPreset preset) {
    final currentPreset = ref.watch(photoToPdfProvider).config.qualityPreset;
    final isSelected = currentPreset == preset;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (selected) async {
        if (selected) {
          final cfg = ref.read(photoToPdfProvider).config.copyWith(qualityPreset: preset);
          ref.read(photoToPdfProvider.notifier).updateConfig(cfg);
          await ref.read(photoToPdfProvider.notifier).generatePdf();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfState = ref.watch(photoToPdfProvider);
    final bytes = pdfState.generatedPdfBytes;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (_currentPageIndex > 1) {
            setState(() => _currentPageIndex--);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (_currentPageIndex < _totalPages) {
            setState(() => _currentPageIndex++);
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                // Gap 13: Export Quality Presets (Small, Medium, Original, Custom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    children: [
                      const Text(
                        'Quality:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQualityChip('Small (72 DPI, 50%)', ImageQualityPreset.low),
                              const SizedBox(width: 6),
                              _buildQualityChip('Medium (150 DPI, 75%)', ImageQualityPreset.medium),
                              const SizedBox(width: 6),
                              _buildQualityChip('Original (Lossless)', ImageQualityPreset.original),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

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
      ),
      ),
    );
  }
}
