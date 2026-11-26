import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/dashboard_screen.dart';
import 'package:mandakhrank/progression_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

void main() {
  for (final mode in ['owner', 'public', 'missing']) {
    testWidgets('profile API to dashboard: $mode', (tester) async {
      final oldClient = PracticeApi.client;
      final oldToken = PracticeApi.token;
      final oldAvatar = PracticeApi.avatarUrl;
      final paths = <String>[];
      PracticeApi.token = 'test';
      PracticeApi.avatarUrl = null;
      final owner = mode != 'public';
      final fixture = <String, dynamic>{
        'id': 1, 'username': 'learner', 'joined_at': '2026-01-01T00:00:00Z',
        'is_owner': owner, if (owner) 'email': 'learner@example.test',
        'avatar_url': null,
        'statistics': {'points': 70, 'solved': 4, 'submissions': 13, 'courses': 16},
        'recent': [], 'can_comment': true, 'comments': [], 'next_before': null,
        if (mode != 'missing') 'progression': {
          'xp': 90, 'level': 1, 'rank': 'Суралцагч', 'xp_in_level': 90,
          'xp_per_level': 250, 'current_streak': 1, 'longest_streak': 2,
          'solved': 4, 'lessons': 1, 'courses': 0, 'contests': 0,
          'totals': {'problems': 300, 'lessons': 160, 'courses': 16},
          'achievements': [{'id': 'solve_1', 'title': 'Анхны алхам', 'category': 'Бодлого', 'description': '1 бодлого', 'icon': 'code', 'progress': 4, 'target': 1, 'unlocked': true}],
          'heatmap': [for (var i = 0; i < 140; i++) {'date': DateTime(2026, 7, 10).add(Duration(days: i)).toIso8601String().substring(0, 10), 'count': i == 139 ? 1 : 0}],
        },
      };
      PracticeApi.client = MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode(fixture), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        PracticeApi.client.close(); PracticeApi.client = oldClient;
        PracticeApi.token = oldToken; PracticeApi.avatarUrl = oldAvatar;
        tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(theme: MandakhPalette.original.themeData(), home: Scaffold(body: SingleChildScrollView(child: StudentDashboard(
        userId: owner ? null : 1, catalog: const {'courses': []},
        onNavigate: (_) {}, onLogin: () async {}, onAvatarChanged: () {}, onOpenProfile: (_) {},
      )))));
      await tester.pumpAndSettle();
      expect(paths.any((p) => p.endsWith(owner ? '/profile/me/' : '/profile/public/1/')), isTrue);
      if (mode == 'missing') {
        expect(find.byKey(const ValueKey('progression-unavailable')), findsOneWidget);
        expect(find.byType(ProgressionOverview), findsNothing);
      } else {
        expect(find.byType(ProgressionOverview), findsOneWidget);
        expect(find.byType(ProgressionAchievements), findsOneWidget);
        expect(find.byType(ProgressionHeatmap), findsOneWidget);
        expect(find.text('Нийт 90 XP'), findsOneWidget);
        expect(find.text('4 / 300'), findsOneWidget);
        expect(find.text('1 / 160'), findsOneWidget);
        expect(find.byKey(const ValueKey('progression-unavailable')), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
