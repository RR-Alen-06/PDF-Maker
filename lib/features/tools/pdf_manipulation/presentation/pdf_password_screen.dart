import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history/services/history_storage_service.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/services/pdf_operations_service.dart';

class PdfPasswordScreen extends StatefulWidget {
  const PdfPasswordScreen({super.key});

  @override
  State<PdfPasswordScreen> createState() => _PdfPasswordScreenState();
}

class _PdfPasswordScreenState extends State<PdfPasswordScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _protectPdfPath;
  String? _unlockPdfPath;

  // Add Password fields
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _passwordMismatchError;

  // Remove Password fields & Lockout countdown
  final TextEditingController _unlockPasswordController = TextEditingController();
  bool _obscureUnlockPassword = true;
  int _unlockFailedAttempts = 0;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _tabController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _unlockPasswordController.dispose();
    super.dispose();
  }

  void _validatePasswordMatch() {
    final p1 = _passwordController.text;
    final p2 = _confirmPasswordController.text;
    if (p2.isNotEmpty && p1 != p2) {
      setState(() => _passwordMismatchError = 'Passwords do not match');
    } else {
      setState(() => _passwordMismatchError = null);
    }
  }

  bool get _canProtect =>
      _protectPdfPath != null &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  Future<void> _protectPdf() async {
    if (!_canProtect) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await PdfManipulationService.applyPassword(
        pdfPath: _protectPdfPath!,
        userPassword: _passwordController.text,
        ownerPassword: _passwordController.text,
      );

      final origName = p.basenameWithoutExtension(_protectPdfPath!);
      final fileName = '${origName}_protected.pdf';
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
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to protect: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _startLockoutCountdown() {
    setState(() => _lockoutSecondsRemaining = 30);
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSecondsRemaining > 1) {
        setState(() => _lockoutSecondsRemaining--);
      } else {
        timer.cancel();
        setState(() {
          _lockoutSecondsRemaining = 0;
          _unlockFailedAttempts = 0;
        });
      }
    });
  }

  Future<void> _unlockPdf() async {
    if (_unlockPdfPath == null || _unlockPasswordController.text.isEmpty || _lockoutSecondsRemaining > 0) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await PdfManipulationService.removePassword(
        pdfPath: _unlockPdfPath!,
        password: _unlockPasswordController.text,
      );

      final origName = p.basenameWithoutExtension(_unlockPdfPath!);
      final fileName = '${origName}_unlocked.pdf';
      final file = await FileUtils.savePdfFile(bytes: bytes, fileName: fileName);

      final history = HistoryStorageService();
      await history.addHistoryItem(
        title: fileName,
        filePath: file.path,
        fileSizeBytes: bytes.lengthInBytes,
        pageCount: 1,
      );

      setState(() {
        _isProcessing = false;
        _unlockFailedAttempts = 0;
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
      setState(() => _isProcessing = false);
      _unlockFailedAttempts++;

      if (_unlockFailedAttempts >= 3) {
        _startLockoutCountdown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('3 incorrect attempts. Operation locked for 30 seconds.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incorrect password ($_unlockFailedAttempts/3 attempts)'),
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
        title: const Text('Password Protection'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.lock_rounded), text: 'Add Password'),
            Tab(icon: Icon(Icons.lock_open_rounded), text: 'Remove Password'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Add Password Screen
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
                  label: Text(_protectPdfPath == null ? 'Select PDF to Protect' : p.basename(_protectPdfPath!)),
                ),
                const SizedBox(height: 20),
                // Password Field with Show/Hide toggle
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _validatePasswordMatch();
                  },
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _validatePasswordMatch();
                    },
                  ),
                ),
                const SizedBox(height: 14),
                // Confirm Password Field with Show/Hide toggle
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _validatePasswordMatch();
                  },
                  child: TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      errorText: _passwordMismatchError,
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _validatePasswordMatch();
                    },
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _canProtect && !_isProcessing ? _protectPdf : null,
                  icon: const Icon(Icons.lock_rounded),
                  label: Text(_isProcessing ? 'Encrypting...' : 'Protect PDF'),
                ),
              ],
            ),
          ),

          // 2. Remove Password Screen
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _lockoutSecondsRemaining > 0
                      ? null
                      : () async {
                          final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
                          if (res.isNotEmpty && res.first.path != null) {
                            setState(() => _unlockPdfPath = res.first.path);
                          }
                        },
                  icon: const Icon(Icons.file_open_rounded),
                  label: Text(_unlockPdfPath == null ? 'Select Protected PDF' : p.basename(_unlockPdfPath!)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _unlockPasswordController,
                  obscureText: _obscureUnlockPassword,
                  enabled: _lockoutSecondsRemaining == 0,
                  decoration: InputDecoration(
                    labelText: 'Current PDF Password',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureUnlockPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscureUnlockPassword = !_obscureUnlockPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_lockoutSecondsRemaining > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text(
                          'Locked out for $_lockoutSecondsRemaining seconds',
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _unlockPdfPath != null &&
                          _unlockPasswordController.text.isNotEmpty &&
                          !_isProcessing &&
                          _lockoutSecondsRemaining == 0
                      ? _unlockPdf
                      : null,
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
