import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history_and_settings/services/history_storage_service.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/services/pdf_manipulation_service.dart';

class PdfMergeScreen extends StatefulWidget {
  const PdfMergeScreen({super.key});

  @override
  State<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends State<PdfMergeScreen> {
  final List<String> _selectedPdfs = [];
  bool _isMerging = false;
  File? _savedFile;

  Future<void> _pickPdfs() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      // ignore: deprecated_member_use
      allowMultiple: true,
    );
    if (files.isNotEmpty) {
      setState(() {
        for (final file in files) {
          if (file.path != null && !_selectedPdfs.contains(file.path!)) {
            _selectedPdfs.add(file.path!);
          }
        }
        _savedFile = null;
      });
    }
  }

  Future<void> _mergeAndSave() async {
    if (_selectedPdfs.length < 2) return;
    setState(() => _isMerging = true);

    try {
      final bytes = await PdfManipulationService.mergePdfs(_selectedPdfs);
      final fileName = FileUtils.generateDefaultFileName(prefix: 'Merged_PDF');
      final file = await FileUtils.savePdfFile(bytes: bytes, fileName: fileName);

      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: fileName,
        filePath: file.path,
        fileSizeBytes: bytes.lengthInBytes,
        pageCount: _selectedPdfs.length,
      );

      setState(() {
        _savedFile = file;
        _isMerging = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully merged ${_selectedPdfs.length} PDFs!'),
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
      setState(() => _isMerging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merge failed: $e'),
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
        title: const Text('Merge PDFs'),
        actions: [
          if (_savedFile != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Merged PDF',
              onPressed: () => FileUtils.sharePdf(_savedFile!.path),
            ),
        ],
      ),
      body: _selectedPdfs.isEmpty
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
                        Icons.call_merge_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Combine Multiple PDFs',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select two or more PDF documents to combine them into a single seamless document.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickPdfs,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Select PDF Files'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Drag items to reorder the merge sequence:',
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedPdfs.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final item = _selectedPdfs.removeAt(oldIndex);
                        _selectedPdfs.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final path = _selectedPdfs[index];
                      final name = path.split(Platform.pathSeparator).last;
                      return Card(
                        key: ValueKey(path),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: AppColors.error),
                                onPressed: () {
                                  setState(() => _selectedPdfs.removeAt(index));
                                },
                              ),
                              const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _selectedPdfs.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPdfs,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add PDF'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(120, 52)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectedPdfs.length < 2 || _isMerging ? null : _mergeAndSave,
                      icon: _isMerging
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.call_merge_rounded),
                      label: Text(_isMerging ? 'Merging...' : 'Merge ${_selectedPdfs.length} PDFs'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
