import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mandakhrank/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandakhrank/main.dart';

void main() {
  testWidgets('Navigation, problem search and details', (tester) async {
    PracticeApi.token = null;
    PracticeApi.username = null;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      PracticeApi.client.close();
      PracticeApi.token = null;
      PracticeApi.username = null;
    });
    final demo = jsonDecode(await rootBundle.loadString('assets/demo.json'));
    PracticeApi.client = MockClient(
      (r) async => http.Response(
        jsonEncode({'results': demo[r.url.pathSegments[1]] ?? []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpWidget(const MandakhApp());
    await tester.pumpAndSettle();
    expect(find.text('Нийт эрэмбэ'), findsOneWidget);
    await tester.tap(find.text('Бодлогууд'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Хоёр тооны нийлбэр');
    await tester.pumpAndSettle();
    // Exclude EditableText: the search input contains this same string.
    final problemTitle = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == 'Хоёр тооны нийлбэр',
    );
    expect(problemTitle, findsOneWidget);
    await tester.ensureVisible(problemTitle);
    await tester.tap(problemTitle);
    await tester.pumpAndSettle();
    expect(find.text('Жишээ оролт'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сургалтууд'));
    await tester.pumpAndSettle();
    expect(find.text('Python-ийн үндэс'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
