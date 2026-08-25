import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history/services/history_storage_service.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/services/pdf_operations_service.dart';

class PdfMergeScreen extends StatefulWidget {
  const PdfMergeScreen({super.key});

  @override
  State<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends State<PdfMergeScreen> {
  final List<MergePdfItem> _selectedPdfs = [];
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
      for (final file in files) {
        if (file.path != null && _selectedPdfs.length < 20) {
          final alreadySelected = _selectedPdfs.any((item) => item.path == file.path!);
          if (!alreadySelected) {
            final inspected = await PdfManipulationService.inspectPdf(file.path!);
            _selectedPdfs.add(inspected);
          }
        }
      }
      setState(() => _savedFile = null);
    }
  }

  Future<String?> _promptPasswordDialog(MergePdfItem item, int attempt) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Password Required',
              style: GoogleFonts.sora(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File "${item.name}" is password protected. Enter password (Attempt $attempt/3):',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip File'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Future<String> _generateMergedFileName() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final prefix = 'Merged_$dateStr';
    final targetDir = await FileUtils.getAppPdfDirectory();

    int highest = 0;
    if (await targetDir.exists()) {
      for (final entry in targetDir.listSync()) {
        final fName = p.basename(entry.path);
        final match = RegExp('^${RegExp.escape(prefix)}_(\\d{3})\\.pdf\$').firstMatch(fName);
        if (match != null) {
          final idx = int.tryParse(match.group(1)!) ?? 0;
          if (idx > highest) highest = idx;
        }
      }
    }
    final nextIdx = (highest + 1).toString().padLeft(3, '0');
    return '${prefix}_$nextIdx.pdf';
  }

  Future<void> _mergeAndSave() async {
    if (_selectedPdfs.length < 2) return;
    setState(() => _isMerging = true);

    final readyItems = <MergePdfItem>[];
    final skippedFiles = <String>[];

    for (final item in _selectedPdfs) {
      if (item.isEncrypted) {
        String? validPassword;
        int attempts = 0;
        final bytes = await File(item.path).readAsBytes();

        while (attempts < 3) {
          attempts++;
          final entered = await _promptPasswordDialog(item, attempts);
          if (entered == null) break; // User tapped Skip

          final isValid = PdfManipulationService.testPdfPassword(bytes, entered);
          if (isValid) {
            validPassword = entered;
            break;
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Incorrect password for ${item.name} ($attempts/3)'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }

        if (validPassword != null) {
          readyItems.add(item.copyWith(password: validPassword));
        } else {
          skippedFiles.add(item.name);
        }
      } else {
        readyItems.add(item);
      }
    }

    if (readyItems.length < 2) {
      setState(() => _isMerging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              skippedFiles.isNotEmpty
                  ? 'Cannot merge: ${skippedFiles.join(", ")} was skipped after 3 failed attempts.'
                  : 'At least 2 unlocked PDFs are required to merge.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Suggestion 10: Storage pre-check before merge (sum of inputs + 10% margin)
    final totalInputBytes = readyItems.fold<int>(0, (sum, i) => sum + i.fileSizeBytes);
    final estimatedOutputBytes = (totalInputBytes * 1.10).round();
    final hasSpace = await FileUtils.hasSufficientStorage(minRequiredBytes: estimatedOutputBytes);
    if (!hasSpace) {
      setState(() => _isMerging = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Insufficient Storage'),
            content: Text(
              'Estimated merge size (${FileUtils.formatBytes(estimatedOutputBytes)}) exceeds available device storage. Free space and retry.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    try {
      final bytes = await PdfManipulationService.mergePdfsWithMetadata(readyItems);
      final fileName = await _generateMergedFileName();
      final file = await FileUtils.savePdfFile(bytes: bytes, fileName: fileName);

      final totalPages = readyItems.fold(0, (sum, i) => sum + i.pageCount);
      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: fileName,
        filePath: file.path,
        fileSizeBytes: bytes.lengthInBytes,
        pageCount: totalPages,
      );

      setState(() {
        _savedFile = file;
        _isMerging = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as $fileName (${readyItems.length} merged)'),
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
                    Text(
                      'Combine Multiple PDFs',
                      style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select 2–20 PDF documents to combine them into a single file.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickPdfs,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Select 2–20 PDFs'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedPdfs.length} PDFs selected (Drag to reorder):',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        'Total: ${FileUtils.formatBytes(_selectedPdfs.fold(0, (s, i) => s + i.fileSizeBytes))}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
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
                      final item = _selectedPdfs[index];
                      return Card(
                        key: ValueKey(item.path),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item.pageCount} ${item.pageCount == 1 ? "page" : "pages"} • ${FileUtils.formatBytes(item.fileSizeBytes)}${item.isEncrypted ? " • Locked" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.isEncrypted ? AppColors.tertiary : Colors.grey,
                            ),
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
                    onPressed: _selectedPdfs.length < 20 ? _pickPdfs : null,
                    icon: const Icon(Icons.add_rounded),
                    label: Text('Add (${_selectedPdfs.length}/20)'),
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
