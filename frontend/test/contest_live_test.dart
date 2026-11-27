import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/contest_live_screen.dart';
import 'package:mandakhrank/practice_screen.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/theme_settings.dart';

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
}
