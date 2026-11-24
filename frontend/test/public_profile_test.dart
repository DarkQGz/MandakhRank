import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/main.dart';
import 'package:mandakhrank/theme_settings.dart';

void main() {
  testWidgets('same dashboard on mobile, entire cards open profiles and comments work', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final original = PracticeApi.client;
    final originalToken = PracticeApi.token;
    final originalAvatar = PracticeApi.avatarUrl;
    PracticeApi.token = 'test';
    PracticeApi.avatarUrl = null;
    final comments = <Map<String, dynamic>>[];
    final requestedProfiles = <int>[];
    final people = [
      {'id': 1, 'name': 'learner', 'handle': 'learner', 'school': '', 'score': 100, 'solved': 2, 'rank': 1},
      {'id': 2, 'name': 'writer', 'handle': 'writer', 'school': '', 'score': 40, 'solved': 1, 'rank': 2},
    ];
    http.Response reply(Object data) => http.Response(jsonEncode(data), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
    Map<String, dynamic> profile(int id) => {
      'id': id, 'username': id == 1 ? 'learner' : 'writer', 'joined_at': '2026-01-01T00:00:00Z',
      'is_owner': id == 1, if (id == 1) 'email': 'private@example.org',
      'statistics': {'points': id == 1 ? 100 : 40, 'solved': id == 1 ? 2 : 1, 'submissions': id == 1 ? 15 : 7, 'courses': 4},
      'recent': [{'id': 99, 'title': id == 1 ? 'Миний бодлого' : 'Нийлбэр олох', 'status': 'Accepted', 'passed': 4, 'total': 4, 'created_at': '2026-11-24T00:00:00Z'}],
      'can_comment': true, 'comments': id == 2 ? comments : [], 'next_before': null,
    };
    PracticeApi.client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/rankings/')) return reply({'results': people});
      if (['/problems/', '/courses/', '/contests/'].any((s) => path.endsWith(s))) return reply({'results': []});
      if (path.endsWith('/profile/me/')) return reply(profile(1));
      if (request.method == 'POST') {
        if (path.endsWith('/delete/')) {
          comments.clear();
        } else {
          comments.add({'id': 1, 'author_id': 1, 'author': 'learner', 'body': jsonDecode(request.body)['body'], 'created_at': '2026-11-24T00:00:00Z', 'can_delete': true});
        }
        return reply({'ok': true});
      }
      final match = RegExp(r'/profile/public/(\d+)/$').firstMatch(path);
      if (match == null) throw StateError('Unexpected path: $path');
      final id = int.parse(match.group(1)!);
      requestedProfiles.add(id);
      return reply(profile(id));
    });
    addTearDown(() {
      PracticeApi.client.close(); PracticeApi.client = original;
      PracticeApi.token = originalToken; PracticeApi.avatarUrl = originalAvatar;
      tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MandakhApp(initialPalette: MandakhPalette.orange));
    await tester.pumpAndSettle();
    expect(find.text('Миний самбар'), findsWidgets);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('Зураг оруулах'), findsOneWidget);
    expect(find.text('private@example.org'), findsOneWidget);
    expect(find.text('Сүүлийн илгээлтүүд'), findsOneWidget);
    expect(find.text('Сэтгэгдлүүд'), findsOneWidget);
    expect(find.text('Миний нийтийн профайл'), findsNothing);
    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.pumpAndSettle();
    final top = find.byKey(const ValueKey('rank-card-top-2'));
    await tester.ensureVisible(top);
    await tester.pumpAndSettle();
    // Tap the padding, not the username or an icon.
    await tester.tapAt(tester.getTopLeft(top) + const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(requestedProfiles, contains(2));
    expect(find.text('writer'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Нийлбэр олох'), findsOneWidget);
    expect(find.text('Зураг оруулах'), findsNothing);
    expect(find.text('private@example.org'), findsNothing);
    expect(PracticeApi.avatarUrl, isNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Сайн байна!');
    await tester.ensureVisible(find.text('Илгээх'));
    await tester.tap(find.text('Илгээх'));
    await tester.pumpAndSettle();
    expect(find.text('Сайн байна!'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Сэтгэгдэл устгах'));
    await tester.tap(find.byTooltip('Сэтгэгдэл устгах'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Устгах'));
    await tester.pumpAndSettle();
    expect(find.text('Сайн байна!'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('rank-card-row-2'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopLeft(row) + const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('writer'), findsOneWidget);
    expect(find.text('Сүүлийн илгээлтүүд'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
