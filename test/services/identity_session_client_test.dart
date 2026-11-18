import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/services/identity_session_client.dart';

const proof = '11111111-1111-4111-8111-11111111111122222222-2222-4222-8222-222222222222';
const identityOrigin = 'https://identity.example.test/';
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
        expect(data['requestedRole'], 'merchant');
        expect(data['displayName'], 'متجر اختبار');
        return http.Response(jsonEncode({
          'accessToken': 'a' * 80,
          'expiresInSeconds': 900,
          'account': {'id':'subject-1','role':'merchant','displayName':'متجر اختبار'}
        }), 200);
      }
      expect(request.headers['authorization'], 'Bearer ${'a' * 80}');
      return http.Response(jsonEncode({
        'account': {'id':'subject-1','role':'merchant','displayName':'متجر اختبار'}
      }), 200);
    });
    addTearDown(client.close);
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: client);
    final session = await api.exchange(proofToken: proof,
      requestedRole: 'merchant', displayName: 'متجر اختبار');
    expect(session.role, 'merchant');
    expect(session.id, 'subject-1');
    expect(urls, [
      '${identityOrigin}v1/identity/session',
      '${identityOrigin}v1/identity/me'
    ]);
  });
  test('rejects supplier and mismatched account without signing in', () async {
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: MockClient((request) async => http.Response(jsonEncode({
        'accessToken': 'b' * 80,
        'expiresInSeconds': 900,
        'account': {'id':'user-1','role':'customer'}
      }), 200)));
    await expectLater(api.exchange(proofToken:proof,requestedRole:'supplier'),
      throwsA(isA<IdentitySessionException>()));
    await expectLater(api.exchange(proofToken:proof),
      throwsA(isA<IdentitySessionException>()));
  });
  test('failed proof redemption never returns a session', () async {
    final api = IdentitySessionClient(baseUri: Uri.parse(identityOrigin),
      httpClient: MockClient((_) async => http.Response('{"error":"expired"}',401)));
    await expectLater(api.exchange(proofToken:proof),
      throwsA(isA<IdentitySessionException>()));
  });
}
