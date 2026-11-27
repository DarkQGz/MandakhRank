import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/notification_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

http.Response reply(Object v) => http.Response(jsonEncode(v),200,headers:{'content-type':'application/json; charset=utf-8'});

void main() {
  for (final palette in [MandakhPalette.original, MandakhPalette.light]) {
    testWidgets('inbox filters and persists explicit mark all: ${palette.brightness}', (tester) async {
      tester.view.physicalSize=const Size(360,780);tester.view.devicePixelRatio=1;
      final client=PracticeApi.client,token=PracticeApi.token;
      PracticeApi.token='test';
      final items=<Map<String,dynamic>>[
        {'id':'announcement:1','kind':'announcement','title':'Class notice','body':'Read chapter 1','at':'2026-11-27T10:00:00Z','read':false},
        {'id':'submission:2:Accepted','kind':'verdict','title':'Accepted result','body':'Sum · #2','at':'2026-11-27T09:00:00Z','read':false,'verdict':'Accepted'},
      ];
      int writes=0;
      PracticeApi.client=MockClient((r)async{
        expect(r.url.path.endsWith('/notifications/'),isTrue);
        if(r.method=='POST'){
          writes++;final body=jsonDecode(r.body) as Map;
          expect(body['action'],'read');expect(body['ids'],['announcement:1','submission:2:Accepted']);
          for(final n in items)n['read']=true;
        }
        return reply({'results':items,'unread':items.where((n)=>n['read']==false).length});
      });
      addTearDown((){PracticeApi.client.close();PracticeApi.client=client;PracticeApi.token=token;tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
      await tester.pumpWidget(MaterialApp(theme:palette.themeData(),home:const NotificationScreen(token:'test')));
      await tester.pumpAndSettle();
      expect(find.text('2 уншаагүй'),findsOneWidget);
      await tester.tap(find.text('Зарлал'));await tester.pumpAndSettle();
      expect(find.text('Class notice'),findsOneWidget);expect(find.text('Accepted result'),findsNothing);
      await tester.tap(find.byKey(const ValueKey('notice-read-all')));await tester.pumpAndSettle();
      expect(writes,1);expect(find.text('0 уншаагүй'),findsOneWidget);
      await tester.tap(find.text('Уншаагүй'));await tester.pumpAndSettle();
      expect(find.text('Мэдэгдэл байхгүй.'),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('bell reads only summary and navigates to inbox', (tester) async {
    final client=PracticeApi.client,token=PracticeApi.token;
    PracticeApi.token='test';
    PracticeApi.client=MockClient((r)async=>r.url.queryParameters['summary']=='1'?reply({'unread':3}):reply({'results':[],'unread':0}));
    addTearDown((){PracticeApi.client.close();PracticeApi.client=client;PracticeApi.token=token;});
    await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:const Scaffold(body:NotificationBell(token:'test'))));
    await tester.pumpAndSettle();expect(find.text('3'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notification-bell')));await tester.pumpAndSettle();
    expect(find.text('МЭДЭГДЛИЙН ТӨВ'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('teacher composer requires an audience and does not offer global publication', (tester) async {
    final client=PracticeApi.client,token=PracticeApi.token;PracticeApi.token='teacher';
    PracticeApi.client=MockClient((r)async=>reply({'global_allowed':false,'classrooms':[{'id':5,'name':'Room A'}],'results':[]}));
    addTearDown((){PracticeApi.client.close();PracticeApi.client=client;PracticeApi.token=token;});
    await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:const AnnouncementScreen(token:'teacher')));
    await tester.pumpAndSettle();
    final publish=find.byKey(const ValueKey('notice-publish'));
    expect(tester.widget<FilledButton>(publish).onPressed,isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();
    expect(find.text('Бүх хэрэглэгч'),findsNothing);expect(find.text('Room A'),findsWidgets);
    await tester.tap(find.text('Room A').last);await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('notice-title')),'Notice');
    await tester.enterText(find.byKey(const ValueKey('notice-body')),'Hello');await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(publish).onPressed,isNotNull);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
