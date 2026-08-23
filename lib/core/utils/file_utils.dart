import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class FileUtils {
  FileUtils._();

  /// Format raw byte count into readable KB / MB
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

  /// Default export filename with timestamp pattern
  static String generateDefaultFileName({String prefix = 'Document'}) {
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${prefix}_$dateStr.pdf';
  }

  /// App documents directory for saving generated PDFs
  static Future<Directory> getAppPdfDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${baseDir.path}/PDF_Maker_Exports');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  /// Save PDF bytes to device local storage
  static Future<File> savePdfFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    final pdfDir = await getAppPdfDirectory();
    final sanitizedName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    final file = File('${pdfDir.path}/$sanitizedName');
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
