import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/learning_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

void main(){
  for(final teacher in [false,true]){
    testWidgets('classroom home ${teacher?'teacher':'student'} role on phone',(tester)async{
      tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
      final old=PracticeApi.client, token=PracticeApi.token;
      PracticeApi.token='test';
      PracticeApi.client=MockClient((r)async=>http.Response(jsonEncode({'teacher':teacher,'owned':teacher?[{'id':1,'name':'Python group','owner':'teacher','managing':true}]:[],'joined':teacher?[]:[{'id':1,'name':'Python group','owner':'teacher','managing':false}]}),200,headers:{'content-type':'application/json; charset=utf-8'}));
      addTearDown((){PracticeApi.client.close();PracticeApi.client=old;PracticeApi.token=token;tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
      await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:const ClassroomHomeScreen()));await tester.pumpAndSettle();
      expect(find.text('Python group'),findsOneWidget);expect(find.text('Ангид нэгдэх'),findsOneWidget);expect(find.text('Анги үүсгэх'),teacher?findsOneWidget:findsNothing);expect(tester.takeException(),isNull);
    });
  }
  testWidgets('student sees status without teacher code or reports',(tester)async{
    final old=PracticeApi.client, token=PracticeApi.token;PracticeApi.token='test';
    PracticeApi.client=MockClient((r)async=>http.Response(jsonEncode({'classroom':{'id':1,'name':'Python group','owner':'teacher','managing':false,'archived':false,'assignments':[{'id':1,'title':'Exercise','kind':'problem','target_id':1,'target_title':'Example','available':true,'status':'overdue','due_at':'2026-01-01T00:00:00Z'}]}}),200,headers:{'content-type':'application/json; charset=utf-8'}));
    addTearDown((){PracticeApi.client.close();PracticeApi.client=old;PracticeApi.token=token;});
    await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:const ClassroomDetailScreen(classroomId:1)));await tester.pumpAndSettle();
    expect(find.text('Хугацаа хэтэрсэн'),findsOneWidget);expect(find.text('Ангийн код'),findsNothing);expect(find.text('CSV тайлан'),findsNothing);expect(tester.takeException(),isNull);
  });
}
