import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandakhrank/main.dart';
void main() {
  testWidgets('Navigation, problem search and details', (tester) async {
    await tester.pumpWidget(const MandakhApp());
    await tester.pumpAndSettle();
    expect(find.text('Нийт эрэмбэ'), findsOneWidget);
    await tester.tap(find.text('Бодлогууд'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Хоёр тооны нийлбэр');
    await tester.pumpAndSettle();
    expect(find.text('Хоёр тооны нийлбэр'), findsOneWidget);
    await tester.ensureVisible(find.text('Хоёр тооны нийлбэр'));
    await tester.tap(find.text('Хоёр тооны нийлбэр'));
    await tester.pumpAndSettle();
    expect(find.text('Жишээ оролт'), findsOneWidget);
    await tester.tap(find.byTooltip('Хаах'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сургалтууд'));
    await tester.pumpAndSettle();
    expect(find.text('Python-ийн үндэс'), findsOneWidget);
  });
}
