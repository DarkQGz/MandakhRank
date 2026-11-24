import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mandakhrank/theme_settings.dart';
import 'package:mandakhrank/minigames_screen.dart';
import 'package:mandakhrank/tv_castle_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('each preset has readable text and produces the chosen theme', () {
    for (final p in [MandakhPalette.original, MandakhPalette.light, MandakhPalette.orange, MandakhPalette.purple, MandakhPalette.midnight]) {
      expect(p.isReadable, isTrue);
      expect(MandakhPalette.contrast(p.accentInk, p.surface), greaterThanOrEqualTo(4.5));
      expect(MandakhPalette.contrast(p.accentInk, p.onAccent), greaterThanOrEqualTo(4.5));
      final theme = p.themeData();
      expect(theme.scaffoldBackgroundColor, p.background);
      expect(theme.colorScheme.onSurface, p.text);
      expect(theme.colorScheme.surface, p.surface);
      expect(theme.extension<MandakhTheme>()!.palette, p);
    }
  });

  test('custom palette persists; invalid stored values fall back', () async {
    final custom = MandakhPalette.light.withColor(3, const Color(0xFFB54708));
    await custom.save();
    expect((await MandakhPalette.load()).toJson(), custom.toJson());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MandakhPalette.storageKey, 'not json');
    expect((await MandakhPalette.load()).toJson(), MandakhPalette.original.toJson());
  });

  test('unreadable custom themes are rejected', () async {
    final bad = MandakhPalette.light.withColor(2, Colors.white);
    expect(bad.isReadable, isFalse);
    await expectLater(bad.save(), throwsStateError);
  });

  testWidgets('settings can select a preset and save it', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    MandakhPalette? saved;
    await tester.pumpWidget(MaterialApp(theme: MandakhPalette.original.themeData(), home: Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ThemeSettingsScreen(initial: MandakhPalette.original, onChanged: (value) => saved = value))), child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Улбар шар'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Хадгалах'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();
    expect(saved?.toJson(), MandakhPalette.orange.toJson());
    expect((await MandakhPalette.load()).toJson(), MandakhPalette.orange.toJson());
  });

  testWidgets('game lobby and TV castle screen use the chosen background', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final theme = MandakhPalette.orange.themeData();
    await tester.pumpWidget(MaterialApp(theme: theme, home: const MiniGamesLobby()));
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, MandakhPalette.orange.background);
    expect(find.text('Цайзын тулаан'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(theme: theme, home: const TvCastleBattleScreen()));
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, MandakhPalette.orange.background);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
