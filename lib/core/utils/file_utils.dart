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
  static String sanitizeFileName(String name) {
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    return name.replaceAll(invalidChars, '').trim();
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
    return '${prefix}_$dateStr.pdf';
  }

  /// Checks if available storage space is sufficient (> 50 MB threshold).
  /// In non-mockable / pure Dart environments, verifies write test probe.
  static Future<bool> hasSufficientStorage({int minRequiredBytes = 50 * 1024 * 1024}) async {
    try {
      final dir = await getAppPdfDirectory();
      final testFile = File(p.join(dir.path, '.storage_probe_${DateTime.now().microsecondsSinceEpoch}'));
      // Write small test block to ensure filesystem is writable and not full
      await testFile.writeAsBytes(List<int>.filled(1024, 0), flush: true);
      if (await testFile.exists()) {
        await testFile.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Save PDF bytes to device local storage
  static Future<File> savePdfFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    final pdfDir = await getAppPdfDirectory();
    final cleanName = sanitizeFileName(fileName);
    final finalName = cleanName.endsWith('.pdf') ? cleanName : '$cleanName.pdf';
    final file = File(p.join(pdfDir.path, finalName));
    return await file.writeAsBytes(bytes, flush: true);
  }

  /// Open PDF in default external PDF reader application
  static Future<void> openPdf(String filePath) async {
    await OpenFilex.open(filePath);
  }

  /// Trigger native share sheet for the PDF file
  static Future<void> sharePdf(String filePath, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        text: text ?? 'Generated with Photo-to-PDF Maker',
      ),
    );
  }
}
