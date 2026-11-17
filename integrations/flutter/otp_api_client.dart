import 'dart:convert';
import 'package:http/http.dart' as http;

/// Transport only. Tokens must be issued by a trusted identity service
/// after OTP verification; the current OTP transport returns no JWT.
class OtpApiClient {
  OtpApiClient({required this.baseUri, http.Client? client})
      : _client = client ?? http.Client() {
    if (baseUri.scheme != 'https') {
      throw ArgumentError('OTP API requires HTTPS');
    }
  }

  final Uri baseUri;
  final http.Client _client;

  Future<OtpRequestResult> request(String phone) async {
    final response = await _client.post(
      baseUri.resolve('/v1/auth/otp/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'purpose': 'login'}),
    );
    if (response.statusCode != 202) {
      throw OtpApiException(response.statusCode);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return OtpRequestResult(
      requestId: json['requestId'] as String,
      expiresInSeconds: json['expiresInSeconds'] as int,
      retryAfterSeconds: json['retryAfterSeconds'] as int,
    );
  }

  Future<bool> verify(String requestId, String code) async {
    final response = await _client.post(
      baseUri.resolve('/v1/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'requestId': requestId, 'code': code}),
    );
    if (response.statusCode != 200) {
      throw OtpApiException(response.statusCode);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['verified'] == true;
  }

  void close() => _client.close();
}

class OtpRequestResult {
  const OtpRequestResult({
    required this.requestId,
    required this.expiresInSeconds,
    required this.retryAfterSeconds,
  });
  final String requestId;
  final int expiresInSeconds;
  final int retryAfterSeconds;
}

class OtpApiException implements Exception {
  const OtpApiException(this.statusCode);
  final int statusCode;
  @override
  String toString() => 'OTP request failed (HTTP $statusCode)';
}
