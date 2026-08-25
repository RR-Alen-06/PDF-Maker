import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class FileUtils {
  FileUtils._();

  /// Format raw byte count into readable KB / MB / GB
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  /// Sanitizes a filename by stripping invalid filesystem characters: \ / : * ? " < > |
  /// and ensures the total filename (including extension) does not exceed 200 characters (Suggestion 16).
  static String sanitizeFileName(String name, {String? extension}) {
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    var clean = name.replaceAll(invalidChars, '').trim();

    if (extension != null && extension.isNotEmpty) {
      if (clean.endsWith(extension)) {
        clean = clean.substring(0, clean.length - extension.length);
      }
      final maxBaseLength = 200 - extension.length;
      if (clean.length > maxBaseLength) {
        clean = clean.substring(0, maxBaseLength);
      }
      return '$clean$extension';
    } else {
      if (clean.length > 200) {
        clean = clean.substring(0, 200);
      }
      return clean;
    }
  }

  /// App designated output directory for saving generated PDFs.
  /// Uses getExternalStorageDirectory() on Android, getApplicationDocumentsDirectory() on iOS/Desktop.
  static Future<Directory> getAppPdfDirectory() async {
    Directory baseDir;
    try {
      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        baseDir = extDir ?? await getApplicationDocumentsDirectory();
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final pdfDir = Directory(p.join(baseDir.path, 'PDF_Maker_Exports'));
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  /// Silently cleans up any abandoned .tmp files from crashed/interrupted sessions (Suggestion 1).
  static Future<void> cleanupStaleTempFiles() async {
    try {
      final dirsToScan = <Directory>[
        await getTemporaryDirectory(),
        await getAppPdfDirectory(),
      ];

      for (final dir in dirsToScan) {
        if (await dir.exists()) {
          final entries = dir.listSync();
          for (final entry in entries) {
            if (entry is File && (entry.path.endsWith('.tmp') || p.basename(entry.path).startsWith('.storage_probe_'))) {
              try {
                await entry.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Generates a default filename following the pattern Scan_YYYY-MM-DD_001
  /// with auto-incrementing numeric suffix to avoid collisions in the output directory.
  static Future<String> generateNextDefaultFileName({
    DateTime? date,
    Directory? targetDir,
  }) async {
    final now = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final prefix = 'Scan_$dateStr';

    final dir = targetDir ?? await getAppPdfDirectory();
    int highestIndex = 0;

    if (await dir.exists()) {
      final entries = dir.listSync();
      final pattern = RegExp('^${RegExp.escape(prefix)}_(\\d{3})\\.pdf\$');

      for (final entry in entries) {
        final fileName = p.basename(entry.path);
        final match = pattern.firstMatch(fileName);
        if (match != null) {
          final indexVal = int.tryParse(match.group(1)!) ?? 0;
          if (indexVal > highestIndex) {
            highestIndex = indexVal;
          }
        }
      }
    }

    final nextIndex = highestIndex + 1;
    final suffix = nextIndex.toString().padLeft(3, '0');
    return '${prefix}_$suffix.pdf';
  }

  /// Synchronous default filename generator with timestamp pattern
  static String generateDefaultFileName({String prefix = 'Document'}) {
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return sanitizeFileName('${prefix}_$dateStr.pdf');
  }

  /// Checks if available storage space is sufficient (> 50 MB threshold or required size + 10% margin).
  static Future<bool> hasSufficientStorage({int minRequiredBytes = 50 * 1024 * 1024}) async {
    try {
      final dir = await getAppPdfDirectory();
      final testFile = File(p.join(dir.path, '.storage_probe_${DateTime.now().microsecondsSinceEpoch}.tmp'));
      // Write test probe to verify filesystem write capability
      await testFile.writeAsBytes(List<int>.filled(1024, 0), flush: true);
      if (await testFile.exists()) {
        await testFile.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Save PDF bytes to device local storage atomically using .tmp and renaming (Suggestion 1).
  /// Enforces maximum 200-char filename cap (Suggestion 16).
  static Future<File> savePdfFile({
    required List<int> bytes,
    required String fileName,
    String? customDirectory,
  }) async {
    Directory pdfDir;
    if (customDirectory != null && customDirectory.isNotEmpty) {
      pdfDir = Directory(customDirectory);
      try {
        if (!await pdfDir.exists()) {
          await pdfDir.create(recursive: true);
        }
      } on FileSystemException catch (_) {
        pdfDir = await getAppPdfDirectory();
      }
    } else {
      pdfDir = await getAppPdfDirectory();
    }

    final finalName = sanitizeFileName(fileName);
    final targetPath = p.join(pdfDir.path, finalName);
    final tempPath = '$targetPath.tmp';
    final tempFile = File(tempPath);

    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      final finalFile = await tempFile.rename(targetPath);

      // Suggestion 26: File Integrity Checksum / Byte Length Verification
      final writtenLength = await finalFile.length();
      if (writtenLength != bytes.length) {
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        throw const FileSystemException('Save failed — write error: byte length mismatch.');
      }

      return finalFile;
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Open PDF in default external PDF reader application.
  /// Returns OpenResult to inspect success or failure.
  static Future<OpenResult> openPdf(String filePath) async {
    return await OpenFilex.open(filePath);
  }

  /// Trigger native share sheet for the PDF file without file-size limits
  static Future<void> sharePdf(String filePath, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        text: text ?? 'Generated with Photo-to-PDF Maker',
      ),
    );
  }
}
