import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/solution_showcase_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

const first = {'id': 11, 'problem_id': 1, 'title': 'First task', 'difficulty': 'Easy', 'language': 'python', 'shared': false};
const second = {'id': 12, 'problem_id': 2, 'title': 'Second task', 'difficulty': 'Hard', 'language': 'cpp', 'shared': false};
http.Response reply(Object data, [int status = 200]) => http.Response(jsonEncode(data), status, headers: {'content-type':'application/json; charset=utf-8'});

void main() {
  test('highlighting preserves exact display text for all five languages', () {
    for (final language in ['python','c','cpp','java','javascript']) {
      const code = 'if (a < 10) {\n  print("text"); // comment\n}\n';
      final spans = highlightSolution(code, language, MandakhPalette.original);
      expect(spans.map((s) => s.text).join(), code);
    }
  });
  testWidgets('private defaults, filters, bulk choices and confirmation', (tester) async {
    final old = PracticeApi.client, token = PracticeApi.token;
    PracticeApi.token = 'test';
    Map<String,dynamic>? posted;
    PracticeApi.client = MockClient((r) async {
      if (r.method == 'POST') { posted = Map<String,dynamic>.from(jsonDecode(r.body) as Map); return reply({'results':[first]}); }
      return reply({'results':[first,second], 'shared_ids':[]});
    });
    tester.view.physicalSize = const Size(390, 1000); tester.view.devicePixelRatio = 1;
    addTearDown(() { PracticeApi.client.close(); PracticeApi.client = old; PracticeApi.token = token; tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.original.themeData(), home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SolutionPrivacyScreen(userId: 1))), child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    final a = find.byKey(const ValueKey('showcase-choice-11')), b = find.byKey(const ValueKey('showcase-choice-12'));
    expect(tester.widget<CheckboxListTile>(a).value, false);
    expect(tester.widget<CheckboxListTile>(b).value, false);
    await tester.tap(find.byKey(const ValueKey('showcase-filter-shared'))); await tester.pumpAndSettle();
    expect(a, findsNothing); expect(b, findsNothing);
    await tester.tap(find.byKey(const ValueKey('showcase-share-all'))); await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(a).value, true);
    expect(tester.widget<CheckboxListTile>(b).value, true);
    await tester.tap(find.byKey(const ValueKey('showcase-hide-all'))); await tester.pumpAndSettle();
    expect(a, findsNothing);
    await tester.tap(find.byKey(const ValueKey('showcase-filter-hidden'))); await tester.pumpAndSettle();
    expect(a, findsOneWidget); expect(b, findsOneWidget);
    await tester.ensureVisible(a); await tester.pumpAndSettle(); await tester.tap(a); await tester.pumpAndSettle();
    expect(a, findsNothing); expect(b, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('showcase-save'))); await tester.pumpAndSettle();
    expect(posted, isNull);
    await tester.tap(find.byKey(const ValueKey('showcase-confirm'))); await tester.pumpAndSettle();
    expect(posted, {'ids':[11], 'previous_ids':[]});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('public profile lists only shared rows and opens code on demand', (tester) async {
    final old = PracticeApi.client, token = PracticeApi.token;
    PracticeApi.token = null;
    var reads = 0;
    PracticeApi.client = MockClient((r) async { reads++; return reply({...first, 'shared':true,'code':'print(42)\n'}); });
    addTearDown(() { PracticeApi.client.close(); PracticeApi.client = old; PracticeApi.token = token; });
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.light.themeData(), home: Scaffold(body: ProfileSolutionsSection(userId:1, rows:[{...first,'shared':true}], owner:false,onManage:null))));
    expect(find.byKey(const ValueKey('showcase-manage')), findsNothing);
    expect(find.text('Second task'), findsNothing);
    expect(reads, 0);
    await tester.tap(find.byKey(const ValueKey('showcase-open-11'))); await tester.pumpAndSettle();
    expect(reads,1); expect(find.byKey(const ValueKey('showcase-code')),findsOneWidget);
    expect(find.byKey(const ValueKey('showcase-copy')),findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
