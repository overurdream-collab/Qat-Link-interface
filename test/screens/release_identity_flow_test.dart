import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/screens/fin25_otp_screen.dart';
import 'package:qat_link/screens/identity_account_screen.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('SMS is never requested automatically and failed OTP never authenticates', (tester) async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 503);
    });
    await tester.pumpWidget(MaterialApp(theme: AppTheme.build(dark: false),
      home: Fin25OtpScreen(phone: '+967771234567',
        baseUri: Uri.parse('https://api.example.test/'),
        identityBaseUri: Uri.parse('https://api.example.test/'), httpClient: client)));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.ensureVisible(find.byKey(const Key('otp_request')));
    await tester.tap(find.byKey(const Key('otp_request')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(IdentityAccountScreen), findsNothing);
    expect(find.textContaining('متوقفة'), findsOneWidget);
    client.close();
  });

  testWidgets('phone proof requires session exchange and matching me before account opens', (tester) async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      final payload = switch (request.url.path) {
        '/v1/auth/otp/public-request' => {'requestId':'11111111-1111-4111-8111-111111111111','expiresInSeconds':300},
        '/v1/auth/otp/verify' => {'verified':true,'proofToken':'11111111-1111-4111-8111-11111111111122222222-2222-4222-8222-222222222222'},
        '/v1/identity/session' => {'accessToken':'x' * 80,'expiresInSeconds':900,'account':{'id':'synthetic','role':'customer'}},
        '/v1/identity/me' => {'account':{'id':'synthetic','role':'customer'}},
        _ => throw StateError('Unexpected route'),
      };
      return http.Response(jsonEncode(payload),200);
    });
    await tester.pumpWidget(MaterialApp(theme: AppTheme.build(dark: false),
      home: Fin25OtpScreen(phone: '+967771234567',
        baseUri: Uri.parse('https://api.example.test/'),
        identityBaseUri: Uri.parse('https://api.example.test/'), httpClient: client)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('otp_request')));
    await tester.tap(find.byKey(const Key('otp_request')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('otp_code')), '123456');
    await tester.ensureVisible(find.byKey(const Key('otp_verify')));
    await tester.tap(find.byKey(const Key('otp_verify')));
    await tester.pumpAndSettle();
    expect(paths, ['/v1/auth/otp/public-request','/v1/auth/otp/verify',
      '/v1/identity/session','/v1/identity/me']);
    expect(find.byType(IdentityAccountScreen), findsOneWidget);
    // Session confirmation presents no synthetic financial dashboard or balance.
    await tester.scrollUntilVisible(
      find.byKey(const Key('open_verified_fin08_overview')), 150);
    expect(find.byKey(const Key('open_verified_fin08_overview')), findsOneWidget);
    client.close();
  });
}
