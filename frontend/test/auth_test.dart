import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/auth_screen.dart';
import 'package:mandakhrank/data.dart';

void main() {
  tearDown(() {
    PracticeApi.token = null;
    PracticeApi.username = null;
  });
  testWidgets('Fourth digit verifies once and signs in automatically', (
    tester,
  ) async {
    var calls = 0;
    PracticeApi.client = MockClient((r) async {
      calls++;
      expect(r.url.path, '/api/auth/verify/');
      expect(jsonDecode(r.body)['code'], '0007');
      expect(jsonDecode(r.body)['email'], 'student@example.com');
      return http.Response(
        jsonEncode({'token': 'session', 'username': 'student'}),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Код оруулах / шинэ код авах'));
    await tester.tap(find.text('Код оруулах / шинэ код авах'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Бүртгүүлсэн имэйл'),
      'student@example.com',
    );
    await tester.enterText(find.byKey(const Key('verification-code')), '000');
    await tester.pump();
    expect(calls, 0);
    await tester.enterText(find.byKey(const Key('verification-code')), '0007');
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(PracticeApi.token, 'session');
    expect(find.byType(AuthScreen), findsNothing);
  });
  testWidgets('Invalid code stays on verification screen and clears input', (
    tester,
  ) async {
    PracticeApi.client = MockClient(
      (_) async => http.Response(jsonEncode({'error': 'Invalid code'}), 400),
    );
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.ensureVisible(find.text('Код оруулах / шинэ код авах'));
    await tester.tap(find.text('Код оруулах / шинэ код авах'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('verification-code')), '1234');
    await tester.pumpAndSettle();
    expect(PracticeApi.token, isNull);
    expect(find.text('Exception: Invalid code'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('verification-code')),
    );
    expect(field.controller!.text, isEmpty);
  });
}
