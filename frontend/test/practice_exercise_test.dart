import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandakhrank/practice_bank.dart';
import 'package:mandakhrank/lesson_practice.dart';
import 'package:mandakhrank/theme_settings.dart';

void main() {
  test('all 160 exercises accept their canonical answer and reject empty or multiline input', () {
    expect(practiceBank.length, 160);
    for (final entry in practiceBank.entries) {
      final e = entry.value;
      expect(e.accepts(e.answer), isTrue, reason: entry.key);
      expect(e.accepts(''), isFalse, reason: entry.key);
      expect(e.accepts('${e.answer}\n'), isFalse, reason: entry.key);
      expect(e.prompt.isNotEmpty, isTrue, reason: entry.key);
      expect(e.sourceExample.isNotEmpty, isTrue, reason: entry.key);
    }
    expect(practiceBank['Хувьсагч ба өгөгдлийн төрөл']!.accepts('true'), isFalse);
    expect(practiceBank['Функцийн оролт']!.accepts('w*h'), isTrue);
    expect(practiceBank['WHERE ба ORDER BY']!.accepts('desc'), isTrue);
    expect(practiceBank['Branch үүсгэх']!.accepts('- c'), isFalse);
  });
  testWidgets('phone practice checks incorrect and correct answers', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.original.themeData(), home: const Scaffold(body: SingleChildScrollView(padding: EdgeInsets.all(16), child: LessonPractice(lesson: {'title':'Хувьсагч ба өгөгдлийн төрөл','example':'age = 20; print(type(age).__name__)'})))));
    final field = find.byKey(const ValueKey('practice-answer'));
    final button = find.text('Хариулт шалгах');
    await tester.enterText(field, 'true');
    await tester.pumpAndSettle(); await tester.ensureVisible(button); await tester.pumpAndSettle(); await tester.tap(button); await tester.pumpAndSettle();
    expect(find.text('Дахин оролдоорой.'), findsOneWidget);
    await tester.enterText(field, 'True');
    await tester.pumpAndSettle(); await tester.ensureVisible(button); await tester.pumpAndSettle(); await tester.tap(button); await tester.pumpAndSettle();
    expect(find.text('Зөв хариулт!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('edited lesson uses ungraded scratchpad', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.original.themeData(), home: const Scaffold(body: SingleChildScrollView(child: LessonPractice(lesson: {'title':'Хувьсагч ба өгөгдлийн төрөл','example':'x = 2','practice':'Өөрийн код бич.'})))));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Хариулт шалгах'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
