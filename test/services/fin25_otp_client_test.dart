import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/services/fin25_otp_client.dart';

void main() {
  test('normalizes Yemeni phone numbers', () {
    expect(() => Fin25OtpClient.normalizeYemeniPhone('٧٧٦٦٤٤٣١٢'), throwsA(isA<Fin25OtpException>()));
    expect(Fin25OtpClient.normalizeYemeniPhone('967776644312'), '+967776644312');
    expect(Fin25OtpClient.normalizeYemeniPhone('727123456'), '+967727123456');
    expect(() => Fin25OtpClient.normalizeYemeniPhone('+966551234567'), throwsA(isA<Fin25OtpException>()));
    expect(Fin25OtpClient.normalizeYemeniPhone('751234567'), '+967751234567');
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
        return http.Response('{"verified":true,"proofToken":"11111111-1111-4111-8111-11111111111122222222-2222-4222-8222-222222222222"}', 200);
      }),
    );
    final challenge = await client.request('776644312');
    await expectLater(client.verify(requestId: challenge.requestId, code: '١٢٣٤٥٦'), throwsA(isA<Fin25OtpException>()));
    await client.verify(requestId: challenge.requestId, code: '123456');
    expect(paths, ['/v1/auth/otp/request', '/v1/auth/otp/verify']);
  });

  test('configured mobile requests use only globally budgeted public endpoint', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(jsonEncode({
        'requestId': '11111111-1111-4111-8111-111111111111',
        'expiresInSeconds': 300
      }), 202);
    });
    addTearDown(client.close);
    final api = Fin25OtpClient(
      baseUri: Uri.parse('https://api.example.test/'),
      httpClient: client, usePublicRequest: true);
    await api.request('776644312');
    expect(paths, ['/v1/auth/otp/public-request']);
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
