import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/learning_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

void main() {
  testWidgets('capstone editor submits and shows server result on phone', (tester) async {
    tester.view.physicalSize = const Size(360,800);
    tester.view.devicePixelRatio=1;
    final old=PracticeApi.client, oldToken=PracticeApi.token;
    PracticeApi.token='test';
    var posted=false;
    PracticeApi.client=MockClient((request) async {
      expect(request.url.path,endsWith('/learning/1/project/'));
      if(request.method=='POST') {
        expect(jsonDecode(request.body)['source'],'print(42)');
        posted=true;
        return http.Response('{}',201,headers:{'content-type':'application/json; charset=utf-8'});
      }
      final body={'project':{'title':'Жишээ төсөл','goal':'Дадлага','requirements':['Тоо хэвлэ.'],'contract':'Нэг тоо хэвлэнэ.','starter':'# TODO','mode':'python','sample_input':'','sample_output':'42','test_count':9},'unlocked':true,'completed':posted,'attempts':posted?[{'status':'Accepted','passed':true,'tests_passed':9,'tests_total':9,'created_at':'2026-01-01T00:00:00Z'}]:[]};
      return http.Response(jsonEncode(body),200,headers:{'content-type':'application/json; charset=utf-8'});
    });
    addTearDown(() {PracticeApi.client.close();PracticeApi.client=old;PracticeApi.token=oldToken;tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
    await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:const CourseProjectScreen(courseId:1)));
    await tester.pumpAndSettle();
    expect(find.text('Жишээ төсөл'),findsOneWidget);
    await tester.ensureVisible(find.text('2. Гүйцэтгэх'));await tester.tap(find.text('2. Гүйцэтгэх'));await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));await tester.enterText(find.byType(TextField),'print(42)');await tester.pumpAndSettle();
    final submit=find.text('Judge-д илгээх');await tester.ensureVisible(submit);await tester.pumpAndSettle();await tester.tap(submit);await tester.pumpAndSettle();
    expect(posted,isTrue);expect(find.text('Зөв бодолт'),findsOneWidget);expect(find.text('9 / 9 тест'),findsOneWidget);expect(tester.takeException(),isNull);
  });
  testWidgets('profile project section displays completion without private code', (tester) async {
    await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:Scaffold(body:ProjectProfileSection(data:{'count':1,'total':16,'completed':[{'title':'ATM систем','course':'Python'}]}))));
    expect(find.text('Төгсгөлийн төслүүд'),findsOneWidget);expect(find.text('1 / 16'),findsOneWidget);expect(find.text('ATM систем'),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
