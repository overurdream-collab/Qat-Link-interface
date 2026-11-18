import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/screens/fin25_pilot_setup_screen.dart';
import 'package:qat_link/screens/fin25_otp_screen.dart';

void main() {
  test('pilot accepts an HTTPS origin and rejects credentials or path', () {
    expect(fin25PilotOrigin(' https://test.example '), Uri.parse('https://test.example/'));
    for (final bad in ['http://test.example', 'https://localhost',
      'https://127.0.0.1', 'https://user:pass@test.example',
      'https://test.example/v1', 'https://test.example?key=secret',
      'https://test.example#secret', '']) {
      expect(fin25PilotOrigin(bad), isNull, reason: bad);
    }
  });

  testWidgets('setup validates and opens OTP without sending automatically', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Fin25PilotSetupScreen()));
    await tester.tap(find.byKey(const Key('pilot_continue')));
    await tester.pumpAndSettle();
    expect(find.byType(Fin25OtpScreen), findsNothing);
    await tester.enterText(find.byKey(const Key('pilot_url')), 'https://test.example');
    await tester.enterText(find.byKey(const Key('pilot_phone')), '700000009');
    await tester.ensureVisible(find.byKey(const Key('pilot_continue')));
    await tester.tap(find.byKey(const Key('pilot_continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otp_request')), findsOneWidget);
    expect(find.byKey(const Key('otp_code')), findsNothing);
  });

  testWidgets('one tap sequence creates one request and verifies without login', (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    var verifications = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/request')) {
        requests++;
        return pending.future;
      }
      verifications++;
      return http.Response('{"verified":true,"proofToken":"11111111-1111-4111-8111-11111111111122222222-2222-4222-8222-222222222222"}', 200);
    });
    addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home: Fin25OtpScreen(
      phone: '+967700000009', baseUri: Uri.parse('https://test.example/'),
      httpClient: client)));
    expect(requests, 0);
    await tester.tap(find.byKey(const Key('otp_request')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('otp_request')));
    await tester.pump();
    expect(requests, 1);
    pending.complete(http.Response(
      '{"requestId":"11111111-1111-4111-8111-111111111111","expiresInSeconds":300}', 202));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otp_request_id')), findsOneWidget);
    expect(find.byKey(const Key('otp_request')), findsNothing);
    await tester.enterText(find.byKey(const Key('otp_code')), '123456');
    await tester.ensureVisible(find.byKey(const Key('otp_verify')));
    await tester.tap(find.byKey(const Key('otp_verify')));
    await tester.pumpAndSettle();
    expect(verifications, 1);
    expect(find.textContaining('تم التحقق من ملكية الرقم.'), findsOneWidget);
    expect(find.textContaining('never-show-this'), findsNothing);
    expect(find.byKey(const Key('otp_verify')), findsNothing);
    expect(find.byType(Fin25OtpScreen), findsOneWidget);
  });
}
