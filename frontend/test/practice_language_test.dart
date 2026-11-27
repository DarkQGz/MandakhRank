import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/practice_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

void main() {
  testWidgets('switching language preserves drafts and submits language', (tester) async {
    final oldClient = PracticeApi.client;
    final oldToken = PracticeApi.token;
    final oldName = PracticeApi.username;
    Map<String, dynamic>? posted;
    PracticeApi.token = 'test';
    PracticeApi.username = 'student';
    PracticeApi.client = MockClient((request) async {
      if (request.method == 'POST') {
        posted = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        return http.Response('{"id":1,"status":"Queued"}', 201);
      }
      return http.Response('{"results":[],"languages":["python","c","cpp","java","javascript"]}', 200);
    });
    tester.view.physicalSize = const Size(1280, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      PracticeApi.client.close();
      PracticeApi.client = oldClient;
      PracticeApi.token = oldToken;
      PracticeApi.username = oldName;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.original.themeData(), home: PracticeScreen(problem: {
      'id': 1, 'title': 'Addition', 'description': 'Add two integers', 'input': '3 7', 'output': '10',
    })));
    await tester.pumpAndSettle();
    final editor = find.byType(TextField);
    await tester.ensureVisible(editor);
    await tester.enterText(editor, 'print(10)');
    Future<void> select(String from, String label) async {
      final dropdown = find.byKey(ValueKey('judge-language-$from'));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }
    await select('python', 'C++ (C++17)');
    expect(tester.widget<TextField>(editor).controller!.text, contains('#include <iostream>'));
    await tester.ensureVisible(editor);
    await tester.enterText(editor, 'int main() { return 0; }');
    await select('cpp', 'Python 3');
    expect(tester.widget<TextField>(editor).controller!.text, 'print(10)');
    await select('python', 'C++ (C++17)');
    expect(tester.widget<TextField>(editor).controller!.text, 'int main() { return 0; }');
    final send = find.text('Илгээж шалгуулах');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(posted, {'problem_id': 1, 'code': 'int main() { return 0; }', 'language': 'cpp'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
