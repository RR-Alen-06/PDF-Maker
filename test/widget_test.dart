import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_maker/main.dart';

void main() {
  testWidgets('App smoke test - verifies HomeScreen renders with hero action',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PdfMakerApp()));
    await tester.pumpAndSettle();

    expect(find.text('PDF STUDIO'), findsOneWidget);
    expect(find.text('Photo to High-Res PDF'), findsOneWidget);
    expect(find.text('Merge PDFs'), findsOneWidget);
    expect(find.text('Compress Images'), findsOneWidget);
  });
}
