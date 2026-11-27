import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/contest_live_screen.dart';
import 'package:mandakhrank/practice_screen.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/theme_settings.dart';
import 'package:mandakhrank/teacher_screen.dart';

Map<String, dynamic> fixture({bool upcoming = false, bool ended = false}) => {
  'id': 12, 'title': 'Test round', 'description': '', 'announcement': '',
  'starts_at': upcoming ? '2026-01-01T01:00:00Z' : '2026-01-01T00:00:00Z',
  'ends_at': '2026-01-01T02:00:00Z',
  'server_time': ended ? '2026-01-01T02:01:00Z' : '2026-01-01T00:30:00Z',
  'status': upcoming ? 'Удахгүй' : ended ? 'Дууссан' : 'Явагдаж байна',
  'can_submit': !upcoming && !ended, 'signed_in': true, 'judge_ready': true,
  'pending': ended ? 1 : 0, 'final': false,
  'problems': upcoming ? [] : [{'id': 41, 'label': 'A', 'title': 'Task A', 'statement': 'Add integers', 'input': '1 2', 'output': '3', 'points': 100}],
  'standings': [],
};
http.Response reply(Object data) => http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  for (final upcoming in [true,false]) {
    testWidgets('contest uses live route and displays appropriate tasks: $upcoming', (tester) async {
      final client=PracticeApi.client, token=PracticeApi.token;
      PracticeApi.token='test';
      PracticeApi.client=MockClient((r) async {
        expect(r.url.path.endsWith('/contests/12/live/'), isTrue);
        return reply(fixture(upcoming:upcoming));
      });
      addTearDown(() {PracticeApi.client.close(); PracticeApi.client=client; PracticeApi.token=token;});
      await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:const ContestLiveScreen(contestId:12,title:'Test round')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('contest-countdown')),findsOneWidget);
      expect(find.text('Task A'),upcoming?findsNothing:findsOneWidget);
      expect(find.byKey(const ValueKey('contest-task-41')),upcoming?findsNothing:findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('contest editor submits only to contest route and obeys admission closure', (tester) async {
    final client=PracticeApi.client, token=PracticeApi.token, name=PracticeApi.username;
    PracticeApi.token='test'; PracticeApi.username='student';
    var open=true; var posts=0;
    PracticeApi.client=MockClient((r) async {
      expect(r.url.path.endsWith('/contests/12/tasks/41/submissions/'),isTrue);
      if(r.method=='POST') {
        final body=jsonDecode(r.body) as Map;
        expect(body['problem_id'],41); expect(body['language'],'python');
        posts++; open=false;
        return reply({'id':100,'status':'Queued'});
      }
      return reply({'results':[],'languages':['python','cpp'],'can_submit':open});
    });
    addTearDown((){PracticeApi.client.close();PracticeApi.client=client;PracticeApi.token=token;PracticeApi.username=name;});
    await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:PracticeScreen(problem:{'id':41,'title':'Task A','description':'Add integers','input':'1 2','output':'3','points':100},contestId:12)));
    await tester.pumpAndSettle();
    final submit=find.ancestor(of:find.text('Илгээж шалгуулах'),matching:find.byWidgetPredicate((w)=>w is FilledButton));
    await tester.ensureVisible(submit); await tester.tap(submit); await tester.pumpAndSettle();
    expect(posts,1); expect(tester.widget<FilledButton>(submit).onPressed,isNull);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('task status precedence, including judge errors', () {
    expect(contestTaskState({'solved':true,'pending':1,'attempts':3,'latest_status':'Wrong Answer'}),'solved');
    expect(contestTaskState({'pending':1,'attempts':2}),'pending');
    expect(contestTaskState({'attempts':1,'latest_status':'Compilation Error'}),'incorrect');
    expect(contestTaskState({'attempts':1,'latest_status':'Judge Error'}),'judge-error');
    expect(contestTaskState({}),'unsolved');
  });
  for (final entry in <(MandakhPalette, Size)>[
    (MandakhPalette.original,const Size(1280,900)),
    (MandakhPalette.light,const Size(360,780)),
    (MandakhPalette.purple,const Size(320,720)),
    (const MandakhPalette(Color(0xFFF7F0D8),Color(0xFFEFE4C2),Color(0xFF36250D),Color(0xFF705020)),const Size(390,844)),
  ]) {
    testWidgets('competition design adapts to ${entry.$2} / ${entry.$1.accent}', (tester) async {
      tester.view.physicalSize=entry.$2; tester.view.devicePixelRatio=1;
      final client=PracticeApi.client, token=PracticeApi.token, name=PracticeApi.username;
      PracticeApi.token='test'; PracticeApi.username='student';
      final data=fixture();
      data['viewer_id']=7; data['viewer_is_student']=true;
      data['problems']=[for(var i=0;i<5;i++) {'id':41+i,'label':String.fromCharCode(65+i),'title':'Task ${String.fromCharCode(65+i)}','statement':'Add integers','input':'1 2','output':'3','points':100}];
      data['standings']=[
        {'user_id':8,'participant':'student-with-a-very-long-username','rank':1,'score':200,'penalty':17,'solved':2,'tasks':{'41':{'solved':true},'42':{'solved':true}}},
        {'user_id':7,'participant':'student','rank':2,'score':100,'penalty':25,'solved':1,'tasks':{
          '41':{'solved':true,'pending':1,'attempts':3}, '42':{'pending':1,'attempts':1},
          '43':{'attempts':1,'latest_status':'Wrong Answer'},'44':{'attempts':1,'latest_status':'Judge Error'}}},
        {'user_id':9,'participant':'other','rank':3,'score':50,'penalty':10,'solved':1,'tasks':{}},
      ];
      PracticeApi.client=MockClient((r) async => reply(data));
      addTearDown((){PracticeApi.client.close();PracticeApi.client=client;PracticeApi.token=token;PracticeApi.username=name;tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
      await tester.pumpWidget(MaterialApp(theme:entry.$1.themeData(),home:const ContestLiveScreen(contestId:12,title:'Test round')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('contest-countdown')),findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('contest-metric-0'))).data,'1/5');
      expect(tester.widget<Text>(find.byKey(const ValueKey('contest-metric-1'))).data,'100');
      expect(tester.widget<Text>(find.byKey(const ValueKey('contest-metric-2'))).data,'25');
      for (final item in <int,String>{41:'Бодсон',42:'Шалгаж байна',43:'Буруу илгээлт',44:'Шүүгчийн алдаа',45:'Бодоогүй'}.entries) {
        expect(tester.widget<Text>(find.byKey(ValueKey('contest-state-${item.key}'))).data,item.value);
      }
      // Opening the problem details must render real text, not a release ErrorWidget.
      final disclosure = find.byKey(const ValueKey('contest-example-41'));
      final details = find.byKey(const ValueKey('contest-details-41'));
      expect(details, findsNothing);
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(details, findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('contest-statement-41'))).data, 'Add integers');
      expect(tester.widget<Text>(find.byKey(const ValueKey('contest-input-41'))).data, '1 2');
      expect(tester.widget<Text>(find.byKey(const ValueKey('contest-output-41'))).data, '3');
      expect(tester.getSize(details).height, lessThan(400));
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(details, findsNothing);
      final board=find.byKey(const ValueKey('contest-scoreboard'));
      await tester.ensureVisible(board); await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('contest-own-row')),findsOneWidget);
      final rows=tester.widget<DataTable>(board).rows;
      expect(rows[0].color!.resolve(<WidgetState>{}),isNot(rows[1].color!.resolve(<WidgetState>{})));
      final viewport = find.byKey(const ValueKey('contest-scoreboard-scroll'));
      final viewportWidth = tester.getSize(viewport).width;
      final tableWidth = tester.getSize(board).width;
      final availableWidth = entry.$2.width - 32.0;
      final expectedWidth = (availableWidth > 1180.0 ? 1180.0 : availableWidth) - 18.0;

      expect(viewportWidth, closeTo(expectedWidth, 0.1));

      if (entry.$2.width >= 1000) {
        expect(tableWidth, closeTo(viewportWidth, 0.1));
      } else {
        expect(tableWidth, greaterThan(viewportWidth));
      }
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('teacher automatic summary shows real accepted count', (tester) async {
    final client=PracticeApi.client, token=PracticeApi.token;
    PracticeApi.token='teacher';
    PracticeApi.client=MockClient((r) async => reply({'classrooms':0,'students':2,'assignments':0,'problems':[], 'contests':[
      {'id':12,'title':'Auto round','status':'Дууссан','starts_at':'2026-01-01T00:00:00Z','ends_at':'2026-01-01T01:00:00Z','auto_judge':true,'participant_count':2,'pending':0,
       'problems':[{'id':41,'label':'A','title':'Task A','points':10,'accepted_count':2,'attempted_count':2,'pending_count':0,'results':[{'participant':'student','score':10,'penalty':2},{'participant':'other','score':10,'penalty':3}]}]},
    ]}));
    addTearDown((){PracticeApi.client.close();PracticeApi.client=client;PracticeApi.token=token;});
    await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:const TeacherWorkspaceScreen()));
    await tester.pumpAndSettle();
    final exp=find.text('Бодлого ба дүн');
    await tester.ensureVisible(exp); await tester.tap(exp); await tester.pumpAndSettle();
    expect(find.text('10 оноо · 2/2 оролцогч бодсон · 0 шалгах илгээлт'),findsOneWidget);
    expect(find.text('A · student'),findsOneWidget);
    expect(find.text('10 оноо · 0 дүн'),findsNothing);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
