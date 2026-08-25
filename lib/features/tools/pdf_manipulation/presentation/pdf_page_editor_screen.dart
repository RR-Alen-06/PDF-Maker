import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history/services/history_storage_service.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/services/pdf_operations_service.dart';

class PdfPageEditorScreen extends StatefulWidget {
  const PdfPageEditorScreen({super.key});

  @override
  State<PdfPageEditorScreen> createState() => _PdfPageEditorScreenState();
}

class _PdfPageItem {
  final int originalPageNumber; // 1-indexed
  final Uint8List? thumbnailBytes;
  final int rotationDegrees; // 0, 90, 180, 270

  const _PdfPageItem({
    required this.originalPageNumber,
    this.thumbnailBytes,
    this.rotationDegrees = 0,
  });

  _PdfPageItem copyWith({
    int? originalPageNumber,
    Uint8List? thumbnailBytes,
    int? rotationDegrees,
  }) {
    return _PdfPageItem(
      originalPageNumber: originalPageNumber ?? this.originalPageNumber,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }
}

class _PdfPageEditorScreenState extends State<PdfPageEditorScreen> {
  String? _selectedPdfPath;
  List<_PdfPageItem> _pages = [];
  final Set<int> _selectedIndices = {};
  final List<List<_PdfPageItem>> _undoStack = [];
  final List<List<_PdfPageItem>> _redoStack = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isGridView = false;
  int _gridColumns = 3;
  File? _savedFile;

  void _pushUndoState() {
    _undoStack.add(List<_PdfPageItem>.from(_pages));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List<_PdfPageItem>.from(_pages));
    setState(() {
      _pages = _undoStack.removeLast();
      _selectedIndices.clear();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List<_PdfPageItem>.from(_pages));
    setState(() {
      _pages = _redoStack.removeLast();
      _selectedIndices.clear();
    });
  }

  Future<void> _pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isNotEmpty && files.first.path != null) {
      final path = files.first.path!;
      setState(() {
        _selectedPdfPath = path;
        _isLoading = true;
        _pages = [];
        _selectedIndices.clear();
        _undoStack.clear();
        _redoStack.clear();
        _savedFile = null;
      });

      final bytes = await File(path).readAsBytes();
      final pageList = <_PdfPageItem>[];

      try {
        int pageIndex = 0;
        await for (final page in Printing.raster(bytes, dpi: 150)) {
          final pngBytes = await page.toPng();
          pageList.add(_PdfPageItem(
            originalPageNumber: pageIndex + 1,
            thumbnailBytes: pngBytes,
          ));
          pageIndex++;
        }
      } catch (_) {
        // Fallback: create placeholder cards if raster fails
        final inspected = await PdfManipulationService.inspectPdf(path);
        for (int i = 0; i < inspected.pageCount; i++) {
          pageList.add(_PdfPageItem(originalPageNumber: i + 1));
        }
      }

      setState(() {
        _pages = pageList;
        _isLoading = false;
        _isGridView = pageList.length > 10;
      });
    }
  }

  void _rotateSelectedPages(bool clockwise) {
    if (_selectedIndices.isEmpty) return;
    _pushUndoState();

    setState(() {
      final updated = List<_PdfPageItem>.from(_pages);
      for (final idx in _selectedIndices) {
        final item = updated[idx];
        final delta = clockwise ? 90 : -90;
        final newRot = (item.rotationDegrees + delta + 360) % 360;
        updated[idx] = item.copyWith(rotationDegrees: newRot);
      }
      _pages = updated;
    });
  }

  void _confirmDeleteSelectedPages() {
    if (_selectedIndices.isEmpty) return;
    final count = _selectedIndices.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Pages?'),
        content: Text('Are you sure you want to delete $count selected page(s)? This can be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _pushUndoState();
              setState(() {
                final sortedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
                for (final idx in sortedIndices) {
                  _pages.removeAt(idx);
                }
                _selectedIndices.clear();
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEditedPdf() async {
    if (_selectedPdfPath == null || _pages.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final pageOrder = _pages.map((p) => p.originalPageNumber).toList();
      final pageRotations = <int, int>{};
      for (final p in _pages) {
        if (p.rotationDegrees != 0) {
          pageRotations[p.originalPageNumber] = p.rotationDegrees;
        }
      }

      final bytes = await PdfManipulationService.reorganizePdf(
        pdfPath: _selectedPdfPath!,
        pageOrder: pageOrder,
        pageRotations: pageRotations,
      );

      final origName = p.basenameWithoutExtension(_selectedPdfPath!);
      final fileName = '${origName}_edited.pdf';
      final file = await FileUtils.savePdfFile(bytes: bytes, fileName: fileName);

      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: fileName,
        filePath: file.path,
        fileSizeBytes: bytes.lengthInBytes,
        pageCount: _pages.length,
      );

      setState(() {
        _savedFile = file;
        _isSaving = false;
        _undoStack.clear();
        _redoStack.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as $fileName'),
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
          SnackBar(content: Text('Failed to save edited PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Page Editor'),
        actions: [
          if (_pages.isNotEmpty) ...[
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
              tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Undo',
              onPressed: _undoStack.isNotEmpty ? _undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              tooltip: 'Redo',
              onPressed: _redoStack.isNotEmpty ? _redo : null,
            ),
            IconButton(
              icon: const Icon(Icons.rotate_90_degrees_ccw_rounded),
              tooltip: 'Rotate 90° CCW',
              onPressed: _selectedIndices.isNotEmpty ? () => _rotateSelectedPages(false) : null,
            ),
            IconButton(
              icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
              tooltip: 'Rotate 90° CW',
              onPressed: _selectedIndices.isNotEmpty ? () => _rotateSelectedPages(true) : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Delete Selected',
              onPressed: _selectedIndices.isNotEmpty ? _confirmDeleteSelectedPages : null,
            ),
          ],
          if (_savedFile != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Edited PDF',
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
                        Icons.dashboard_customize_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Reorder, Rotate & Delete Pages',
                      style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick any PDF to reorder pages, rotate orientation, or delete unwanted pages.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.file_open_rounded),
                      label: const Text('Select PDF to Edit'),
                    ),
                  ],
                ),
              ),
            )
          : _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Rendering high-res page thumbnails…'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_pages.length} pages (Hold & drag to reorder)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (_selectedIndices.isNotEmpty)
                            Text(
                              '${_selectedIndices.length} selected',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isGridView
                          ? GestureDetector(
                              onScaleUpdate: (details) {
                                if (details.scale > 1.25 && _gridColumns > 2) {
                                  setState(() => _gridColumns = 2);
                                } else if (details.scale < 0.75 && _gridColumns < 4) {
                                  setState(() => _gridColumns = 4);
                                }
                              },
                              child: GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _gridColumns,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.75,
                                ),
                                itemCount: _pages.length,
                                itemBuilder: (context, index) {
                                  final page = _pages[index];
                                  final isSelected = _selectedIndices.contains(index);

                                  return Card(
                                    key: ValueKey(page.originalPageNumber),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isSelected ? AppColors.primary : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedIndices.remove(index);
                                          } else {
                                            _selectedIndices.add(index);
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Transform.rotate(
                                                angle: (page.rotationDegrees * 3.141592653589793) / 180,
                                                child: page.thumbnailBytes != null
                                                    ? Image.memory(page.thumbnailBytes!, fit: BoxFit.contain)
                                                    : const Icon(Icons.picture_as_pdf, color: Colors.grey, size: 40),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            left: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '#${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: -2,
                                            right: -2,
                                            child: Checkbox(
                                              value: isSelected,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedIndices.add(index);
                                                  } else {
                                                    _selectedIndices.remove(index);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _pages.length,
                              onReorderItem: (oldIndex, newIndex) {
                                _pushUndoState();
                                setState(() {
                                  final item = _pages.removeAt(oldIndex);
                                  _pages.insert(newIndex, item);
                                  _selectedIndices.clear();
                                });
                              },
                              itemBuilder: (context, index) {
                                final page = _pages[index];
                                final isSelected = _selectedIndices.contains(index);

                                return Card(
                                  key: ValueKey(page.originalPageNumber),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedIndices.remove(index);
                                        } else {
                                          _selectedIndices.add(index);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        children: [
                                          // Thumbnail preview
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: SizedBox(
                                              width: 60,
                                              height: 80,
                                              child: Transform.rotate(
                                                angle: (page.rotationDegrees * 3.141592653589793) / 180,
                                                child: page.thumbnailBytes != null
                                                    ? Image.memory(page.thumbnailBytes!, fit: BoxFit.contain)
                                                    : Container(
                                                        color: Colors.grey.shade300,
                                                        child: const Icon(Icons.picture_as_pdf, color: Colors.grey),
                                                      ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Page ${index + 1}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Original Page ${page.originalPageNumber} • Rotation: ${page.rotationDegrees}°',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white60 : Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedIndices.add(index);
                                                } else {
                                                  _selectedIndices.remove(index);
                                                }
                                              });
                                            },
                                          ),
                                          const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: _pages.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveEditedPdf,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_alt_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save as <original>_edited.pdf'),
              ),
            ),
    );
  }
}
