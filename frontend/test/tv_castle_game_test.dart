import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandakhrank/tv_castle_game.dart';

void main() {
  testWidgets('TV castle battle opens and starts without a backend', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: TvCastleBattleScreen()));

    expect(find.text('Цайзын тулаан'), findsOneWidget);
    expect(find.text('Математик'), findsOneWidget);
    expect(find.text('Хялбар алгоритм'), findsOneWidget);
    expect(find.text('Дунд шатны алгоритм'), findsOneWidget);
    expect(find.text('Програмчлал'), findsOneWidget);
    expect(find.text('Ерөнхий мэдлэг'), findsOneWidget);

    final start = find.text('ТУЛААН ЭХЛҮҮЛЭХ');
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await tester.pump();

    expect(find.text('ҮЕ 1/10'), findsOneWidget);
    expect(find.textContaining('хамгаалалт'), findsNWidgets(2));
    expect(find.text('Хариултаа сонгоно уу'), findsNWidgets(2));

    // Dispose the screen so its timer and perpetual ambience animation stop.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  });
}
