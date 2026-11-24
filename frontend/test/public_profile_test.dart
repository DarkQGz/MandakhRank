import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/public_profile_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

void main() {
  testWidgets('public profile displays, posts and deletes a comment', (tester) async {
    final original = PracticeApi.client;
    final originalToken = PracticeApi.token;
    PracticeApi.token = 'test';
    final comments = <Map<String, dynamic>>[];
    PracticeApi.client = MockClient((request) async {
      if (request.method == 'POST') {
        if (request.url.path.endsWith('/delete/')) {
          comments.clear();
        } else {
          comments.add({'id': 1, 'author_id': 2, 'author': 'writer', 'body': jsonDecode(request.body)['body'], 'created_at': '2026-11-24T00:00:00Z', 'can_delete': true});
        }
        return http.Response('{"ok":true}', 200);
      }
      return http.Response(jsonEncode({'id': 1, 'username': 'learner', 'joined_at': '2026-01-01T00:00:00Z', 'statistics': {'points': 100, 'solved': 2}, 'can_comment': true, 'comments': comments, 'next_before': null}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    addTearDown(() { PracticeApi.client.close(); PracticeApi.client = original; PracticeApi.token = originalToken; });
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.orange.themeData(), home: const PublicProfileScreen(userId: 1)));
    await tester.pumpAndSettle();
    expect(find.text('learner'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Сайн байна!');
    await tester.tap(find.text('Илгээх'));
    await tester.pumpAndSettle();
    expect(find.text('Сайн байна!'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Сэтгэгдэл устгах'));
    await tester.tap(find.byTooltip('Сэтгэгдэл устгах'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Устгах'));
    await tester.pumpAndSettle();
    expect(find.text('Сайн байна!'), findsNothing);
    expect(find.text('Одоогоор сэтгэгдэл алга.'), findsOneWidget);
  });
}
