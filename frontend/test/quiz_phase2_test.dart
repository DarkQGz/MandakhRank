import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/learning_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

void main() {
  testWidgets('mixed five-question exam, typed answer navigation and server review', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    final old = PracticeApi.client, token = PracticeApi.token;
    PracticeApi.token = 'test';
    int submissions = 0;
    final questions = [
      {'id':'f','kind':'fill','prompt':'is_ready = ___','options':[]},
      {'id':'o','kind':'output','prompt':'print(2+3) ямар гаралттай вэ?', 'options':[{'id':'o1','text':'5'},{'id':'o2','text':'23'}]},
      {'id':'b','kind':'bug','prompt':'Алдааг олно уу.', 'options':[{'id':'b1','text':'Догол мөр'},{'id':'b2','text':'Өнгө'}]},
      {'id':'t','kind':'true_false','prompt':'Python нь case-sensitive.', 'options':[{'id':'t1','text':'Үнэн'},{'id':'t2','text':'Худал'}]},
      {'id':'c','kind':'choice','prompt':'Функц тодорхойлох түлхүүр үг?', 'options':[{'id':'c1','text':'def'},{'id':'c2','text':'else'}]},
    ];
    PracticeApi.client = MockClient((req) async {
      expect(req.url.queryParameters['format'], '2');
      final Map<String,dynamic> body;
      if (req.method == 'POST') {
        submissions++;
        expect(jsonDecode(req.body)['answers'], {'f':'False','o':'o1','b':'b1','t':'t1','c':'c1'});
        body = {'passed':false,'score':80,'correct':4,'total':5,'threshold':100,'review':[
          {'kind':'fill','prompt':'is_ready = ___','correct':false,'selected':'False','answer':'True','explanation':'Энэ жишээнд үнэн утга шаардсан.'},
          {'kind':'output','prompt':'print(2+3) ямар гаралттай вэ?','correct':true,'selected':'5','answer':'5','explanation':'2+3=5.'},
        ]};
      } else {
        body = {'questions':questions,'threshold':100};
      }
      return http.Response(jsonEncode(body),200,headers:{'content-type':'application/json; charset=utf-8'});
    });
    addTearDown(() { PracticeApi.client.close(); PracticeApi.client = old; PracticeApi.token = token; tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.original.themeData(), home: const LearningQuizScreen(courseId:1,lessonId:2)));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('quiz-input-f'));
    final next = find.text('Дараагийн асуулт');
    expect(tester.widget<FilledButton>(find.ancestor(of:next, matching:find.byType(FilledButton))).onPressed, isNull);
    await tester.ensureVisible(field); await tester.enterText(field,'False'); await tester.pumpAndSettle();
    await tester.tap(next); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-nav-0'))); await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).initialValue,'False');
    await tester.tap(next); await tester.pumpAndSettle();
    for (final text in ['5','Догол мөр','Үнэн']) {
      final choice = find.text(text).last;
      await tester.ensureVisible(choice); await tester.tap(choice); await tester.pumpAndSettle();
      await tester.tap(next); await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('def')); await tester.tap(find.text('def')); await tester.pumpAndSettle();
    await tester.tap(find.text('Хариулт илгээх')); await tester.pumpAndSettle();
    expect(submissions,1); expect(find.text('80%'),findsOneWidget);
    final filter = find.text('Зөвхөн алдаа');
    await tester.ensureVisible(filter); await tester.tap(filter); await tester.pumpAndSettle();
    expect(find.text('print(2+3) ямар гаралттай вэ?'),findsNothing);
    await tester.ensureVisible(find.text('is_ready = ___')); await tester.tap(find.text('is_ready = ___')); await tester.pumpAndSettle();
    expect(find.text('Зөв хариулт: True'),findsOneWidget);
    await tester.tap(find.text('Дахин оролдох')); await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).initialValue,'');
    expect(tester.takeException(),isNull);
  });
}
