import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/auth_screen.dart';
import 'package:mandakhrank/data.dart';

Future<void> openVerification(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
    body: TextButton(onPressed: () => Navigator.push(context,
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen())),
      child: const Text('Open'))))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  final openCode = find.text('Код оруулах / шинэ код авах');
  await tester.ensureVisible(openCode);
  await tester.tap(openCode);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('verification-email')), 'student@example.com');
}

Future<void> pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(ready(), isTrue, reason: 'Expected authentication state was not reached. '
    'Screen text: ${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(" | ")}');
}

void main() {
  setUp(() { PracticeApi.token = null; PracticeApi.username = null; });
  tearDown(() {
    PracticeApi.client.close();
    PracticeApi.token = null; PracticeApi.username = null;
  });

  testWidgets('Fourth digit verifies once and signs in automatically', (tester) async {
    final requests = <http.Request>[];
    final serverReply = Completer<http.Response>();
    PracticeApi.client = MockClient((request) {
      // Never put expect() inside this callback: the app catches request errors.
      requests.add(request);
      return serverReply.future;
    });
    addTearDown(() async {
      if (!serverReply.isCompleted) serverReply.complete(http.Response('{"error":"test ended"}',400));
      await tester.pumpWidget(const SizedBox());
    });
    await openVerification(tester);
    final code = find.byKey(const Key('verification-code'));
    await tester.enterText(code, '000');
    await tester.pump();
    expect(requests, isEmpty);
    await tester.enterText(code, '0007');
    await pumpUntil(tester, () => requests.isNotEmpty);
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.url.path, '/api/auth/verify/');
    expect(jsonDecode(request.body), {'email':'student@example.com','code':'0007'});
    expect(PracticeApi.token, isNull); // Still waiting for the server.
    serverReply.complete(http.Response(jsonEncode({'token':'session','username':'student'}),200,
      headers:{'content-type':'application/json; charset=utf-8'}));
    await pumpUntil(tester, () => PracticeApi.token == 'session');
    await tester.pumpAndSettle();
    expect(PracticeApi.username, 'student');
    expect(requests, hasLength(1));
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('Invalid code stays on verification screen and clears input', (tester) async {
    PracticeApi.client = MockClient((_) async => http.Response(
      jsonEncode({'error':'Invalid code'}),400,
      headers:{'content-type':'application/json; charset=utf-8'}));
    addTearDown(() async { await tester.pumpWidget(const SizedBox()); });
    await openVerification(tester);
    final code = find.byKey(const Key('verification-code'));
    await tester.enterText(code,'1234');
    await pumpUntil(tester, () => find.text('Exception: Invalid code').evaluate().isNotEmpty);
    expect(PracticeApi.token,isNull);
    expect(find.byType(AuthScreen),findsOneWidget);
    expect(tester.widget<TextField>(code).controller!.text,isEmpty);
  });
}
