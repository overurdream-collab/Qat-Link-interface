import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/services/maqwati_api_config.dart';

void main() {
  test('unified origin fails closed for unsafe or temporary endpoints', () {
    for (final value in ['', 'http://api.example.test',
      'https://localhost', 'https://127.0.0.1', 'https://[::1]',
      'https://phone.local', 'https://a.trycloudflare.com',
      'https://u:p@api.example.test', 'https://api.example.test/path',
      'https://api.example.test?secret=x', 'https://api.example.test#fragment',
      'https://api.example.test:8443']) {
      expect(MaqwatiApiConfig.parseOrigin(value), isNull, reason: value);
    }
    expect(MaqwatiApiConfig.parseOrigin('https://api.example.test')?.toString(),
      'https://api.example.test/');
  });
}
