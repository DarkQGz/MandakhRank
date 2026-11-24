import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/main.dart';
import 'package:mandakhrank/practice_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(430, 932), const Size(1280, 800)]) {
    testWidgets('ranking and problem layout at $size', (tester) async {
      final old = PracticeApi.client;
      final token = PracticeApi.token;
      PracticeApi.token = null;
      PracticeApi.client = MockClient((r) async => http.Response(jsonEncode({'results': r.url.path.endsWith('/rankings/') ? List.generate(3, (i) => {'id': i+1, 'rank': i+1, 'name': 'long-student-username-${i+1}', 'handle': 'student${i+1}', 'school': '', 'score': 1000, 'solved': 30}) : []}), 200, headers: {'content-type': 'application/json; charset=utf-8'}));
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() { PracticeApi.client.close(); PracticeApi.client = old; PracticeApi.token = token; tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
      await tester.pumpWidget(const MandakhApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rank-card-top-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(theme: MandakhPalette.original.themeData(), home: const PracticeScreen(problem: {'id':1,'title':'Нийлбэр','description':'Хоёр тоог нэмнэ.','input':'3 7','output':'10','difficulty':'Хялбар','points':20})));
      await tester.pumpAndSettle();
      expect(find.text('Жишээ оролт'), findsOneWidget);
      expect(find.text('Нэвтрэх / Бүртгүүлэх'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
