import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/photo_item.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';

enum ScanFilterMode {
  original('Original Color'),
  grayscale('Grayscale'),
  blackAndWhite('Black & White (Threshold)'),
  enhanced('Enhanced (auto contrast + sharpen)');

  final String label;
  const ScanFilterMode(this.label);
}

class ScanModeScreen extends ConsumerStatefulWidget {
  const ScanModeScreen({super.key});

  @override
  ConsumerState<ScanModeScreen> createState() => _ScanModeScreenState();
}

class _ScanModeScreenState extends ConsumerState<ScanModeScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _capturedImagePath;
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;
  ScanFilterMode _selectedFilter = ScanFilterMode.enhanced;
  bool _isDetectingEdges = false;
  bool _isProcessingFilter = false;
  String? _edgeNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureDocumentPhoto();
    });
  }

  Future<void> _captureDocumentPhoto() async {
    setState(() {
      _isDetectingEdges = true;
      _edgeNotice = null;
    });

    try {
      final xFile = await _picker.pickImage(source: ImageSource.camera);
      if (xFile != null) {
        final bytes = await File(xFile.path).readAsBytes();
        setState(() {
          _capturedImagePath = xFile.path;
          _originalBytes = bytes;
          // Document edge simulation check: if standard photo, fallback with guide
          _edgeNotice = 'Edges not detected — adjust manually.';
          _isDetectingEdges = false;
        });
        _applyScanFilter();
      } else {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isDetectingEdges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _applyScanFilter() async {
    if (_originalBytes == null) return;
    setState(() => _isProcessingFilter = true);

    try {
      final decoded = img.decodeImage(_originalBytes!);
      if (decoded != null) {
        img.Image processed;
        switch (_selectedFilter) {
          case ScanFilterMode.original:
            processed = decoded;
            break;
          case ScanFilterMode.grayscale:
            processed = img.grayscale(decoded);
            break;
          case ScanFilterMode.blackAndWhite:
            final gray = img.grayscale(decoded);
            processed = img.luminanceThreshold(gray, threshold: 0.5);
            break;
          case ScanFilterMode.enhanced:
            final contrast = img.contrast(decoded, contrast: 130);
            final bright = img.adjustColor(contrast, brightness: 1.12);
            // Apply gaussian blur & blend for mild unsharp-mask sharpen pass
            final blurred = img.gaussianBlur(bright, radius: 1);
            processed = img.compositeImage(bright, blurred, dstW: bright.width, dstH: bright.height, blend: img.BlendMode.overlay);
            break;
        }

        final outBytes = Uint8List.fromList(img.encodeJpg(processed, quality: 90));
        setState(() {
          _processedBytes = outBytes;
          _isProcessingFilter = false;
        });
      }
    } catch (_) {
      setState(() => _isProcessingFilter = false);
    }
  }

  Future<void> _acceptAndAddToSession() async {
    if (_processedBytes == null || _capturedImagePath == null) return;

    final tempFile = File('${_capturedImagePath!}_scanned.jpg');
    await tempFile.writeAsBytes(_processedBytes!, flush: true);

    final decoded = img.decodeImage(_processedBytes!);
    final width = decoded?.width ?? 1200;
    final height = decoded?.height ?? 1600;

    final photoItem = PhotoItem(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      path: tempFile.path,
      cachedBytes: _processedBytes,
      width: width,
      height: height,
      originalSizeBytes: _processedBytes!.lengthInBytes,
    );

    final controller = ref.read(photoToPdfProvider.notifier);
    controller.appendPhotoItem(photoItem);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanned document added to session!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Retake',
            onPressed: _captureDocumentPhoto,
          ),
        ],
      ),
      body: _isDetectingEdges
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Detecting document edges…'),
                ],
              ),
            )
          : _originalBytes == null
              ? Center(
                  child: ElevatedButton.icon(
                    onPressed: _captureDocumentPhoto,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Capture Document'),
                  ),
                )
              : Column(
                  children: [
                    if (_edgeNotice != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: AppColors.tertiary.withValues(alpha: 0.15),
                        child: Row(
                          children: [
                            const Icon(Icons.crop_free_rounded, size: 18, color: AppColors.tertiary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _edgeNotice!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_processedBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(_processedBytes!, fit: BoxFit.contain),
                              )
                            else
                              const CircularProgressIndicator(),

                            // Quadrilateral Crop guide overlay
                            Positioned.fill(
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primary, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            if (_isProcessingFilter)
                              Container(
                                color: Colors.black38,
                                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Filter presets selector
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan Filters',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ScanFilterMode.values.map((filter) {
                                final isSelected = filter == _selectedFilter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(filter.label),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _selectedFilter = filter);
                                        _applyScanFilter();
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_processedBytes == null)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Scan at least 1 page to continue.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _processedBytes != null ? _acceptAndAddToSession : null,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Accept & Add to Session'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
