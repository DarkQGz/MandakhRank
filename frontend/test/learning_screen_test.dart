import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/learning_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

void main() {
  testWidgets('mobile lesson steps, hidden example and server quiz result', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    final old = PracticeApi.client, token = PracticeApi.token;
    PracticeApi.token = 'test';
    bool sent = false;
    PracticeApi.client = MockClient((r) async {
      expect(r.url.path, endsWith('/learning/1/quiz/2/'));
      if (r.method == 'POST') {
        expect(jsonDecode(r.body)['answers'], {'1':'b','2':'c'});
        sent = true;
        return http.Response(jsonEncode({'passed':true,'score':100,'correct':2,'total':2,'threshold':100,'review':[]}),200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response(jsonEncode({'questions':[
        {'id':'1','prompt':'Асуулт нэг','options':[{'id':'a','text':'Буруу нэг'},{'id':'b','text':'Зөв нэг'}]},
        {'id':'2','prompt':'Асуулт хоёр','options':[{'id':'c','text':'Зөв хоёр'},{'id':'d','text':'Буруу хоёр'}]},
      ]}),200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    addTearDown(() { PracticeApi.client.close(); PracticeApi.client = old; PracticeApi.token = token; tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.original.themeData(), home: Builder(builder: (context) => Scaffold(body: Center(child: FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LearningLessonScreen(courseId: 1, index: 0, total: 12, lesson: {'id':2,'title':'Хувьсагч','theory':'Утгыг нэрээр хадгална. Дараа ашиглаж болно.','example':'x = 2\nprint(x)','result':'2 гарна','practice':'Утгаа сольж турш.','has_quiz':true}))), child: const Text('Нээх')))))));
    await tester.tap(find.text('Нээх')); await tester.pumpAndSettle();
    expect(find.text('Гол ойлголт'), findsOneWidget);
    await tester.tap(find.text('Дараах алхам')); await tester.pumpAndSettle();
    expect(find.text('2 гарна'), findsNothing);
    await tester.tap(find.text('Үр дүнг харах')); await tester.pumpAndSettle();
    expect(find.text('2 гарна'), findsOneWidget);
    await tester.tap(find.text('Дараах алхам')); await tester.pumpAndSettle();
    expect(find.text('Өөрөө турших'), findsOneWidget);
    await tester.tap(find.text('Дараах алхам')); await tester.pumpAndSettle();
    await tester.tap(find.text('Шалгалт өгөх')); await tester.pumpAndSettle();
    expect(find.text('Асуулт нэг'), findsOneWidget);
    await tester.tap(find.text('Зөв нэг')); await tester.pumpAndSettle();
    await tester.tap(find.text('Дараагийн асуулт')); await tester.pumpAndSettle();
    await tester.tap(find.text('Зөв хоёр')); await tester.pumpAndSettle();
    await tester.tap(find.text('Хариулт илгээх')); await tester.pumpAndSettle();
    expect(sent, isTrue);
    expect(find.text('Амжилттай тэнцлээ!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Дуусгах')); await tester.pumpAndSettle();
    expect(find.text('Нээх'), findsOneWidget);
  });
  testWidgets('course library cards respond to full-card taps', (tester) async {
    tester.view.physicalSize = const Size(360, 800); tester.view.devicePixelRatio = 1;
    addTearDown(() {tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
    int? opened;
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.light.themeData(), home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: LearningLibrary(courses: const [{'id':1,'title':'Python-ийн үндэс','tag':'Python','level':'Анхан шат','description':'Анхны программ','lessons':['Нэг','Хоёр'],'learning':{'completed':1,'total':2,'passed':false}}], onOpen: (row) => opened = row['id'] as int)))));
    expect(find.text('1 / 2 хичээл'), findsOneWidget);
    final card = find.text('Python-ийн үндэс');
    await tester.ensureVisible(card); await tester.tap(card); await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
}
