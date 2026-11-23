import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/main.dart';
import 'package:qat_link/screens/login_screen.dart';
import 'package:qat_link/screens/role_home_screen.dart';
import 'package:qat_link/services/identity_session_client.dart';
import 'package:qat_link/services/session_store.dart';

const _token =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _stored = IdentitySession(
  accessToken: _token,
  id: 'account-one',
  role: 'merchant',
  displayName: 'متجر الأصالة',
);
const _storedRefresh = IdentitySession(
  accessToken: _token,
  id: 'account-one',
  role: 'merchant',
  displayName: 'متجر الأصالة',
  refreshToken: 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr',
);

IdentitySessionClient _client(int status,
    {String role = 'merchant', bool refreshOk = false}) {
  const refreshed = 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn';
  final mock = MockClient((request) async {
    if (request.url.path.endsWith('/v1/identity/logout')) {
      return http.Response('{"revoked":true}', 200);
    }
    if (request.url.path.endsWith('/v1/identity/refresh')) {
      if (!refreshOk) return http.Response('{"error":"expired"}', 401);
      return http.Response(
        jsonEncode({
          'accessToken': refreshed,
          'refreshToken': 'mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm',
          'expiresInSeconds': 900,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith('/v1/identity/me')) {
      final authorized = request.headers['authorization'] == 'Bearer $refreshed';
      if (status != 200 && !(refreshOk && authorized)) {
        return http.Response('{"error":"expired"}', status);
      }
      return http.Response(
        jsonEncode({
          'account': {
            'id': 'account-one',
            'role': role,
            'displayName': 'متجر الأصالة',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"error":"not found"}', 404);
  });
  addTearDown(mock.close);
  return IdentitySessionClient(
    baseUri: Uri.parse('https://api.example.test/'),
    httpClient: mock,
  );
}

void main() {
  testWidgets('no stored session keeps the login screen', (tester) async {
    await tester.pumpWidget(QatLinkApp(sessionStore: MemorySessionStore()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RoleHomeScreen), findsNothing);
  });

  testWidgets('confirmed stored session restores the workspace and logs out',
      (tester) async {
    final store = MemorySessionStore(_stored);
    await tester.pumpWidget(QatLinkApp(
      sessionStore: store,
      sessionClient: _client(200),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(RoleHomeScreen), findsOneWidget);
    expect(find.byKey(const Key('role_home_logout')), findsOneWidget);

    await tester.tap(find.byKey(const Key('role_home_logout')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RoleHomeScreen), findsNothing);
    expect(await store.read(), isNull);
  });

  testWidgets('rejected stored session is cleared and login is shown',
      (tester) async {
    final store = MemorySessionStore(_stored);
    await tester.pumpWidget(QatLinkApp(
      sessionStore: store,
      sessionClient: _client(401),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RoleHomeScreen), findsNothing);
    expect(await store.read(), isNull);
  });

  testWidgets('expired access token refreshes before restoring the workspace',
      (tester) async {
    final store = MemorySessionStore(_storedRefresh);
    await tester.pumpWidget(QatLinkApp(
      sessionStore: store,
      sessionClient: _client(401, refreshOk: true),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(RoleHomeScreen), findsOneWidget);
    final restored = await store.read();
    expect(restored?.accessToken, 'n' * 80);
    expect(restored?.refreshToken, 'm' * 43);
  });

  testWidgets('failed refresh clears the stored session and shows login',
      (tester) async {
    final store = MemorySessionStore(_storedRefresh);
    await tester.pumpWidget(QatLinkApp(
      sessionStore: store,
      sessionClient: _client(401),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RoleHomeScreen), findsNothing);
    expect(await store.read(), isNull);
  });
}
