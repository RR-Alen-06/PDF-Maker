import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';

class ExportSettingsScreen extends ConsumerStatefulWidget {
  const ExportSettingsScreen({super.key});

  @override
  ConsumerState<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends ConsumerState<ExportSettingsScreen> {
  String _folderPath = 'PDF_Maker_Exports';
  final TextEditingController _patternController =
      TextEditingController(text: '{name}_{date}_{counter}');
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExportSettings();
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _loadExportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPattern = prefs.getString('custom_naming_pattern');
    final savedFolder = prefs.getString('custom_export_folder');

    final defaultDir = await FileUtils.getAppPdfDirectory();

    setState(() {
      if (savedPattern != null) _patternController.text = savedPattern;
      _folderPath = savedFolder ?? defaultDir.path;
      _isLoading = false;
    });
  }

  Future<void> _pickFolder() async {
    final picked = await FilePicker.getDirectoryPath();
    if (picked != null) {
      setState(() => _folderPath = picked);
    }
  }

  String _generateLivePreview(String pattern) {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final timeStr = DateFormat('HHmmss').format(DateTime.now());
    final formatted = pattern
        .replaceAll('{name}', 'Document')
        .replaceAll('{date}', dateStr)
        .replaceAll('{time}', timeStr)
        .replaceAll('{counter}', '001')
        .replaceAll('{total}', '10');
    return '$formatted.pdf';
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_naming_pattern', _patternController.text.trim());
    await prefs.setString('custom_export_folder', _folderPath);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export settings persisted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Output folder section
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
                        const Text('Output Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          _folderPath,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickFolder,
                          icon: const Icon(Icons.folder_open_rounded),
                          label: const Text('Change Folder'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Naming pattern section
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
                        const Text('File Naming Pattern', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        const Text(
                          'Available tokens: {name}, {date}, {time}, {counter}, {total}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _patternController,
                          decoration: InputDecoration(
                            labelText: 'Pattern',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        const Text('Live Example Filename:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _generateLivePreview(_patternController.text),
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save & Apply Settings'),
                  ),
                ],
              ),
            ),
    );
  }
}
