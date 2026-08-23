import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history_and_settings/services/history_storage_service.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/services/pdf_manipulation_service.dart';

class PdfPasswordScreen extends StatefulWidget {
  const PdfPasswordScreen({super.key});

  @override
  State<PdfPasswordScreen> createState() => _PdfPasswordScreenState();
}

class _PdfPasswordScreenState extends State<PdfPasswordScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _protectPdfPath;
  String? _unlockPdfPath;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _unlockPasswordController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passwordController.dispose();
    _unlockPasswordController.dispose();
    super.dispose();
  }

  Future<void> _protectPdf() async {
    if (_protectPdfPath == null || _passwordController.text.trim().isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await PdfManipulationService.applyPassword(
        pdfPath: _protectPdfPath!,
        userPassword: _passwordController.text.trim(),
        ownerPassword: _passwordController.text.trim(),
      );

      final fileName = FileUtils.generateDefaultFileName(prefix: 'Protected');
      final file = await FileUtils.savePdfFile(bytes: bytes, fileName: fileName);

      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: fileName,
        filePath: file.path,
        fileSizeBytes: bytes.lengthInBytes,
        pageCount: 1,
      );

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password protection applied successfully!'),
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
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to protect: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _unlockPdf() async {
    if (_unlockPdfPath == null || _unlockPasswordController.text.trim().isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await PdfManipulationService.removePassword(
        pdfPath: _unlockPdfPath!,
        password: _unlockPasswordController.text.trim(),
      );

      final fileName = FileUtils.generateDefaultFileName(prefix: 'Unlocked');
      final file = await FileUtils.savePdfFile(bytes: bytes, fileName: fileName);

      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: fileName,
        filePath: file.path,
        fileSizeBytes: bytes.lengthInBytes,
        pageCount: 1,
      );

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password removed successfully!'),
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
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unlock (Incorrect password?): $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Security'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.lock_rounded), text: 'Set Password'),
            Tab(icon: Icon(Icons.lock_open_rounded), text: 'Remove Password'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Protect Screen
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
                    if (res.isNotEmpty && res.first.path != null) {
                      setState(() => _protectPdfPath = res.first.path);
                    }
                  },
                  icon: const Icon(Icons.file_open_rounded),
                  label: Text(_protectPdfPath == null ? 'Select PDF to Protect' : _protectPdfPath!.split(Platform.pathSeparator).last),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password to Encrypt',
                    prefixIcon: const Icon(Icons.password_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _protectPdfPath != null && !_isProcessing ? _protectPdf : null,
                  icon: const Icon(Icons.lock_rounded),
                  label: Text(_isProcessing ? 'Encrypting...' : 'Protect PDF with Password'),
                ),
              ],
            ),
          ),

          // 2. Unlock Screen
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
                    if (res.isNotEmpty && res.first.path != null) {
                      setState(() => _unlockPdfPath = res.first.path);
                    }
                  },
                  icon: const Icon(Icons.file_open_rounded),
                  label: Text(_unlockPdfPath == null ? 'Select Protected PDF' : _unlockPdfPath!.split(Platform.pathSeparator).last),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _unlockPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current PDF Password',
                    prefixIcon: const Icon(Icons.key_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _unlockPdfPath != null && !_isProcessing ? _unlockPdf : null,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(_isProcessing ? 'Decrypting...' : 'Remove Password'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
