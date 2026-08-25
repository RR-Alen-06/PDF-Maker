import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/tools/image_compressor/services/image_compressor_service.dart';

class ImageCompressorScreen extends StatefulWidget {
  const ImageCompressorScreen({super.key});

  @override
  State<ImageCompressorScreen> createState() => _ImageCompressorScreenState();
}

class _ImageCompressorScreenState extends State<ImageCompressorScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<String> _selectedImagePaths = [];
  List<CompressedImageResult> _compressedResults = [];
  double _quality = 70;
  final TextEditingController _targetSizeController = TextEditingController();
  bool _isProcessing = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _targetSizeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        // Cap at 1-50 images
        for (final file in pickedFiles) {
          if (_selectedImagePaths.length < 50 && !_selectedImagePaths.contains(file.path)) {
            _selectedImagePaths.add(file.path);
          }
        }
      });
      _compressImages();
    }
  }

  void _onSettingsChanged() {
    _debounceTimer?.cancel();
    // 500 ms live preview update debounce
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _selectedImagePaths.isNotEmpty) {
        _compressImages();
      }
    });
  }

  Future<void> _compressImages() async {
    if (_selectedImagePaths.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final targetKb = int.tryParse(_targetSizeController.text.trim());
      final results = await ImageCompressorService.compressBatch(
        imagePaths: _selectedImagePaths,
        quality: _quality.round(),
        targetSizeKb: targetKb != null && targetKb >= 10 ? targetKb : null,
      );

      setState(() {
        _compressedResults = results;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Compression failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportAllCompressed() async {
    if (_compressedResults.isEmpty) return;
    try {
      final exportDir = await FileUtils.getAppPdfDirectory();
      for (final result in _compressedResults) {
        final originalFileName = p.basename(result.originalPath);
        final ext = p.extension(originalFileName);
        final baseName = p.basenameWithoutExtension(originalFileName);
        final outPath = p.join(exportDir.path, '${baseName}_compressed$ext');

        final sourceFile = File(result.outputPath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(outPath);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${_compressedResults.length} images to ${exportDir.path}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  int get _totalOriginalSize =>
      _compressedResults.fold(0, (sum, r) => sum + r.originalSizeBytes);
  int get _totalCompressedSize =>
      _compressedResults.fold(0, (sum, r) => sum + r.compressedSizeBytes);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Compressor'),
        actions: [
          if (_compressedResults.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.save_alt_rounded),
              tooltip: 'Export All',
              onPressed: _exportAllCompressed,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share All',
              onPressed: () {
                final files =
                    _compressedResults.map((r) => XFile(r.outputPath)).toList();
                SharePlus.instance.share(
                  ShareParams(files: files, text: 'Compressed Images'),
                );
              },
            ),
          ],
        ],
      ),
      body: _selectedImagePaths.isEmpty
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
                        Icons.compress_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Dedicated Image Compressor',
                      style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select 1–50 photos from your gallery to reduce file sizes without creating a PDF.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('Select 1–50 Images'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Quality & Target Size Controls Card
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quality Slider',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            '${_quality.round()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _quality,
                        min: 1,
                        max: 100,
                        divisions: 99,
                        onChanged: (val) {
                          setState(() => _quality = val);
                          _onSettingsChanged();
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _targetSizeController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Target Size (KB)',
                                hintText: 'e.g. 500 (Min 10 KB)',
                                suffixText: 'KB',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onChanged: (_) => _onSettingsChanged(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_targetSizeController.text.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                _targetSizeController.clear();
                                _compressImages();
                              },
                              child: const Text('Clear Target'),
                            ),
                        ],
                      ),
                      if (_compressedResults.isNotEmpty) ...[
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total: ${FileUtils.formatBytes(_totalOriginalSize)}  ➜  ${FileUtils.formatBytes(_totalCompressedSize)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '-${(((_totalOriginalSize - _totalCompressedSize) / (_totalOriginalSize > 0 ? _totalOriginalSize : 1)) * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // List of Selected & Compressed Images
                Expanded(
                  child: _isProcessing
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Compressing preview images…'),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _compressedResults.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _compressedResults[index];
                            final fileName = p.basename(item.originalPath);

                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        item.previewBytes,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${FileUtils.formatBytes(item.originalSizeBytes)} ➜ ${FileUtils.formatBytes(item.compressedSizeBytes)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '-${item.reductionPercentage.toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share_outlined, size: 20),
                                      onPressed: () {
                                        SharePlus.instance.share(
                                          ShareParams(files: [XFile(item.outputPath)]),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _selectedImagePaths.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _selectedImagePaths.length < 50 ? _pickImages : null,
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text('Add (${_selectedImagePaths.length}/50)'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(120, 52)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportAllCompressed,
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('Export Compressed'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
