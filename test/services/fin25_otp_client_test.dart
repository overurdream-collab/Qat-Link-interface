import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/services/fin25_otp_client.dart';

void main() {
  test('normalizes Yemeni phone numbers', () {
    expect(Fin25OtpClient.normalizeYemeniPhone('٧٧٦٦٤٤٣١٢'), '+967776644312');
    expect(Fin25OtpClient.normalizeYemeniPhone('967776644312'), '+967776644312');
    expect(() => Fin25OtpClient.normalizeYemeniPhone('123'),
        throwsA(isA<Fin25OtpException>()));
  });

  test('requires HTTPS', () {
    expect(() => Fin25OtpClient(
      baseUri: Uri.parse('http://example.com/'),
      httpClient: MockClient((_) async => http.Response('{}', 200))),
      throwsArgumentError);
  });

  test('request and verify do not issue a financial session', () async {
    final paths = <String>[];
    final client = Fin25OtpClient(
      baseUri: Uri.parse('https://example.com/'),
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/request')) {
          expect(jsonDecode(request.body)['phone'], '+967776644312');
          return http.Response(jsonEncode({
            'requestId': '11111111-1111-4111-8111-111111111111',
            'expiresInSeconds': 300
          }), 202);
        }
        expect(jsonDecode(request.body)['code'], '123456');
        return http.Response('{"verified":true}', 200);
      }),
    );
    final challenge = await client.request('776644312');
    await client.verify(requestId: challenge.requestId, code: '١٢٣٤٥٦');
    expect(paths, ['/v1/auth/otp/request', '/v1/auth/otp/verify']);
  });

  test('rate limit rejects excess requests', () async {
    final client = Fin25OtpClient(
      baseUri: Uri.parse('https://example.com/'),
      httpClient: MockClient((_) async =>
          http.Response('{"error":"Too many requests"}', 429)),
    );
    await expectLater(client.request('776644312'),
        throwsA(isA<Fin25OtpException>()));
  });
}
