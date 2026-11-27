import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/dashboard_screen.dart';
import 'package:mandakhrank/teacher_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

void main(){
  for(final mode in ['teacher-owner','teacher-public','student']){
    testWidgets('teacher identity: $mode',(tester)async{
      final old=PracticeApi.client,token=PracticeApi.token,avatar=PracticeApi.avatarUrl;
      final owner=mode!='teacher-public',teacher=mode!='student';
      PracticeApi.token='test';PracticeApi.avatarUrl=null;
      PracticeApi.client=MockClient((r)async=>http.Response(jsonEncode({
        'id':1,'username':'learner','is_owner':owner,'role':teacher?'teacher':'student','joined_at':'2026-01-01T00:00:00Z',
        'avatar_url':null,'statistics':{'points':0,'solved':0,'submissions':0,'courses':16},'recent':[],
        'can_comment':true,'comments':[],'next_before':null,
      }),200,headers:{'content-type':'application/json; charset=utf-8'}));
      tester.view.physicalSize=const Size(360,850);tester.view.devicePixelRatio=1;
      addTearDown((){PracticeApi.client.close();PracticeApi.client=old;PracticeApi.token=token;PracticeApi.avatarUrl=avatar;tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
      await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:Scaffold(body:SingleChildScrollView(child:StudentDashboard(
        userId:owner?null:1,catalog:const {'courses':[]},onNavigate:(_){},onLogin:()async{},onAvatarChanged:(){},onOpenProfile:(_){},
      )))));await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('teacher-avatar-border')),teacher?findsOneWidget:findsNothing);
      expect(find.byType(TeacherWorkspaceEntry),teacher&&owner?findsOneWidget:findsNothing);
      expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('teacher workspace shows real counts and contest action',(tester)async{
    final old=PracticeApi.client,token=PracticeApi.token;PracticeApi.token='test';
    PracticeApi.client=MockClient((r)async=>http.Response(jsonEncode({'classrooms':2,'students':7,'assignments':4,'contests':[],'problems':[{'id':1,'title':'P','points':10,'difficulty':'Easy'}]}),200,headers:{'content-type':'application/json; charset=utf-8'}));
    tester.view.physicalSize=const Size(360,850);tester.view.devicePixelRatio=1;
    addTearDown((){PracticeApi.client.close();PracticeApi.client=old;PracticeApi.token=token;tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
    await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:const TeacherWorkspaceScreen()));await tester.pumpAndSettle();
    expect(find.text('7'),findsOneWidget);
    final create=find.byKey(const ValueKey('teacher-create-contest'));await tester.ensureVisible(create);await tester.tap(create);await tester.pumpAndSettle();
    expect(find.text('Шинэ тэмцээн'),findsOneWidget);expect(find.text('Бодлого сонгох · 0/12'),findsOneWidget);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
}
