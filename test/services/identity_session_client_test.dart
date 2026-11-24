import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/services/identity_session_client.dart';

const proof = '11111111-1111-4111-8111-11111111111122222222-2222-4222-8222-222222222222';
const identityOrigin = 'https://identity.example.test/';
const deviceId = '33333333-3333-4333-8333-333333333333';
void main() {
  test('identity API requires configured clean HTTPS origin', () {
    for (final bad in ['http://identity.example.test/',
      'https://localhost/', 'https://user:pass@identity.example.test/',
      'https://identity.example.test/v1/']) {
      expect(() => IdentitySessionClient(
        baseUri: Uri.parse(bad),
        httpClient: MockClient((_) async => http.Response('{}', 200))),
        throwsArgumentError);
    }
  });
  test('exchanges OTP proof only with trusted identity server and confirms account', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      if (request.url.path.endsWith('/session')) {
        expect(request.method, 'POST');
        final data = jsonDecode(request.body);
        expect(data['proofToken'], proof);
        expect(data['deviceId'], deviceId);
        expect(data['requestedRole'], 'merchant');
        expect(data['displayName'], 'متجر اختبار');
        return http.Response(jsonEncode({
          'accessToken': 'a' * 80,
          'refreshToken': 'r' * 43,
          'expiresInSeconds': 900,
          'account': {'id':'subject-1','role':'merchant','displayName':'متجر اختبار'}
        }), 200, headers: const {'content-type':'application/json; charset=utf-8'});
      }
      expect(request.headers['authorization'], 'Bearer ${'a' * 80}');
      return http.Response(jsonEncode({
        'account': {'id':'subject-1','role':'merchant','displayName':'متجر اختبار'}
      }), 200, headers: const {'content-type':'application/json; charset=utf-8'});
    });
    addTearDown(client.close);
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: client);
    final session = await api.exchange(proofToken: proof, deviceId: deviceId,
      requestedRole: 'merchant', displayName: 'متجر اختبار');
    expect(session.role, 'merchant');
    expect(session.id, 'subject-1');
    expect(session.refreshToken, 'r' * 43);
    expect(urls, [
      '${identityOrigin}v1/identity/session',
      '${identityOrigin}v1/identity/me'
    ]);
  });
  test('rejects supplier and mismatched account without signing in', () async {
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/me')) {
          return http.Response(jsonEncode({
            'account': {'id':'different-user','role':'customer'}
          }), 200);
        }
        return http.Response(jsonEncode({
          'accessToken': 'b' * 80,
          'refreshToken': 's' * 43,
          'expiresInSeconds': 900,
          'account': {'id':'user-1','role':'customer'}
        }), 200);
      }));
    await expectLater(api.exchange(proofToken:proof,deviceId:deviceId,requestedRole:'supplier'),
      throwsA(isA<IdentitySessionException>()));
    await expectLater(api.exchange(proofToken:proof,deviceId:deviceId),
      throwsA(isA<IdentitySessionException>()));
  });
  test('safe registration-required diagnosis on 409 without revealing server internals', () async {
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: MockClient((_) async => http.Response(
        jsonEncode({'error':'Account registration required'}), 409)));
    await expectLater(api.exchange(proofToken:proof,deviceId:deviceId), throwsA(
      isA<IdentitySessionException>()
        .having((e) => e.statusCode, 'statusCode', 409)
        .having((e) => e.message, 'registration guidance', contains('إنشاء حساب'))));
  });

  test('safe FIN08 provisioning diagnosis on 503 does not grant a session', () async {
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: MockClient((_) async => http.Response(
        jsonEncode({'error':'Financial provisioning unavailable'}), 503)));
    await expectLater(api.exchange(proofToken:proof,deviceId:deviceId), throwsA(
      isA<IdentitySessionException>()
        .having((e) => e.statusCode, 'statusCode', 503)
        .having((e) => e.message, 'FIN08 guidance', contains('FIN08'))));
  });

  test('role conflict is not represented as an unregistered phone', () async {
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: MockClient((_) async => http.Response(
        jsonEncode({'error':'This phone already belongs to another account role'}), 409)));
    await expectLater(api.exchange(proofToken:proof,deviceId:deviceId), throwsA(
      isA<IdentitySessionException>()
        .having((e) => e.message, 'role conflict guidance', contains('نوع حساب مختلف'))));
  });

  test('untrusted error text is never displayed to the user', () async {
    const privateDetail = 'PRIVATE_USER_OR_TOKEN_DETAILS';
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: MockClient((_) async => http.Response(
        jsonEncode({'error':privateDetail}), 500)));
    await expectLater(api.exchange(proofToken:proof,deviceId:deviceId), throwsA(
      isA<IdentitySessionException>()
        .having((e) => e.message, 'no reflected server text',
          allOf(isNot(contains(privateDetail)), contains('HTTP 500')))));
  });

  test('failed proof redemption never returns a session', () async {
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: MockClient((_) async => http.Response('{"error":"expired"}',401)));
    await expectLater(api.exchange(proofToken:proof,deviceId:deviceId),
      throwsA(isA<IdentitySessionException>()));
  });

  test('refreshes a rotated token and confirms the new access token', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      if (request.url.path.endsWith('/refresh')) {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body)['refreshToken'], 'r' * 43);
        expect(jsonDecode(request.body)['deviceId'], deviceId);
        return http.Response(jsonEncode({
          'accessToken': 'n' * 80,
          'refreshToken': 'm' * 43,
          'expiresInSeconds': 900,
        }), 200, headers: const {'content-type':'application/json'});
      }
      expect(request.headers['authorization'], 'Bearer ${'n' * 80}');
      return http.Response(jsonEncode({
        'account': {'id':'subject-1','role':'merchant','displayName':'متجر اختبار'}
      }), 200, headers: const {'content-type':'application/json'});
    });
    addTearDown(client.close);
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: client);
    final session = await api.refresh(refreshToken: 'r' * 43, deviceId: deviceId);
    expect(session.accessToken, 'n' * 80);
    expect(session.refreshToken, 'm' * 43);
    expect(session.id, 'subject-1');
    expect(urls, [
      '${identityOrigin}v1/identity/refresh',
      '${identityOrigin}v1/identity/me'
    ]);
  });

  test('logout posts the access and refresh token without exposing them in errors', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/identity/logout');
      expect(request.headers['authorization'], 'Bearer ${'a' * 80}');
      expect(jsonDecode(request.body)['refreshToken'], 'r' * 43);
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: client);
    await api.logout(accessToken: 'a' * 80, refreshToken: 'r' * 43);
  });

  test('refresh rejects malformed tokens before any network call', () async {
    var calls = 0;
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: MockClient((_) async { calls++; return http.Response('{}', 200); }));
    await expectLater(api.refresh(refreshToken: 'short', deviceId: deviceId),
      throwsA(isA<IdentitySessionException>()));
    expect(calls, 0);
  });
}
