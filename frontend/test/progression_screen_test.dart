import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandakhrank/progression_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

Map<String, dynamic> example() => {
  'xp': 550, 'level': 3, 'xp_in_level': 50, 'xp_per_level': 250,
  'current_streak': 3, 'longest_streak': 7, 'rank': 'Кодлогч',
  'achievements': [
    {'id': 'solve_1', 'title': 'Анхны алхам', 'category': 'Бодлого', 'description': '1 бодлогыг зөв бодох', 'unlocked': true, 'icon': 'code', 'progress': 10, 'target': 1},
    {'id': 'solve_100', 'title': 'Зуун бодлого', 'category': 'Бодлого', 'description': '100 өөр бодлогыг зөв бодох', 'unlocked': false, 'icon': 'trophy', 'progress': 10, 'target': 100},
  ],
  'heatmap': [for (var i=0; i<140; i++) {'date': DateTime(2026, 7, 10).add(Duration(days:i)).toIso8601String().substring(0,10), 'count': i >= 137 ? 1 : 0}],
};

void main() {
  for (final size in [const Size(320,800), const Size(390,844), const Size(1280,800)]) {
    for (final palette in [MandakhPalette.original, MandakhPalette.light]) {
      testWidgets('profile progression renders at $size with ${palette.brightness}', (tester) async {
        tester.view.physicalSize=size;
        tester.view.devicePixelRatio=1;
        addTearDown(() {tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
        final data=example();
        await tester.pumpWidget(MaterialApp(theme: palette.themeData(), home: Scaffold(body: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: Column(children: [
            ProgressionOverview(data:data), ProgressionAchievements(data:data), ProgressionHeatmap(data:data),
          ])))));
        await tester.pumpAndSettle();
        expect(find.text('Level 3'),findsOneWidget);
        expect(find.text('Нийт 550 XP'),findsOneWidget);
        expect(find.text('1 / 2'),findsOneWidget);
        expect(find.text('3 идэвхтэй өдөр · 3 гүйцэтгэл'),findsOneWidget);
        expect(find.byType(Tooltip),findsAtLeastNWidgets(140));
        expect(tester.takeException(),isNull);
        final button=find.text('Бүх амжилт');
        await tester.ensureVisible(button); await tester.pumpAndSettle();
        await tester.tap(button); await tester.pumpAndSettle();
        expect(find.text('1 / 2 амжилт'),findsOneWidget);
        expect(find.text('Анхны алхам'),findsOneWidget);
        expect(find.text('Зуун бодлого'),findsOneWidget);
        final earned=find.widgetWithText(ChoiceChip,'Нээсэн');
        await tester.tap(earned); await tester.pumpAndSettle();
        expect(find.text('Анхны алхам'),findsOneWidget);
        expect(find.text('Зуун бодлого'),findsNothing);
        final locked=find.widgetWithText(ChoiceChip,'Түгжээтэй');
        await tester.tap(locked); await tester.pumpAndSettle();
        expect(find.text('Зуун бодлого'),findsOneWidget);
        expect(find.text('Анхны алхам'),findsNothing);
        expect(tester.takeException(),isNull);
      });
    }
  }
}
