import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../features/auth/auth_input_validation.dart';

/// FIN25 OTP transport only. A verified SMS code does NOT create a session.
class Fin25OtpException implements Exception {
  const Fin25OtpException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class Fin25OtpChallenge {
  const Fin25OtpChallenge(this.requestId, this.expiresInSeconds);
  final String requestId;
  final int expiresInSeconds;
}

class Fin25OtpClient {
  Fin25OtpClient({required this.baseUri, required this.httpClient,
    this.timeout = const Duration(seconds: 15), this.pilotAccessKey}) {
    if (baseUri.scheme != 'https' || baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty || baseUri.hasQuery || baseUri.hasFragment) {
      throw ArgumentError('FIN25 OTP requires a clean HTTPS base URL');
    }
  }
  final Uri baseUri;
  final http.Client httpClient;
  final Duration timeout;
  /// Volatile pilot key supplied by operator; never log or store it.
  final String? pilotAccessKey;

  static String normalizeYemeniPhone(String raw) {
    final normalized = AuthInputValidation.normalizePhone(raw);
    final digits = normalized.startsWith('+967')
        ? normalized.substring(4)
        : normalized.startsWith('967') && normalized.length == 12
            ? normalized.substring(3)
            : normalized;
    if (!RegExp(r'^[0-9]{9}$').hasMatch(digits)) {
      throw const Fin25OtpException(
          'أدخل 9 أرقام إنجليزية (0-9) لرقم جوال يمني.');
    }
    return '+967$digits';
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, String> body) async {
    try {
      final response = await httpClient.post(
        baseUri.resolve(path),
        headers: {'content-type': 'application/json', 'accept': 'application/json',
          if (pilotAccessKey != null) 'x-pilot-key': pilotAccessKey!},
        body: jsonEncode(body),
      ).timeout(timeout);
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException('Invalid response');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = switch (response.statusCode) {
          429 => 'محاولات كثيرة. انتظر قبل طلب رمز آخر.',
          400 => 'رقم الهاتف أو رمز التحقق غير صحيح.',
          401 => 'رمز التحقق غير صحيح أو انتهت صلاحيته.',
          503 => 'خدمة رسائل التحقق متوقفة حالياً.',
          _ => 'تعذر إكمال الطلب. حاول لاحقاً.',
        };
        throw Fin25OtpException(message, statusCode: response.statusCode);
      }
      return value;
    } on Fin25OtpException { rethrow; }
      on TimeoutException { throw const Fin25OtpException('انتهت مهلة الاتصال. لا تكرر الطلب فوراً.'); }
      on FormatException { throw const Fin25OtpException('رد غير مفهوم من الخادم.'); }
      on http.ClientException { throw const Fin25OtpException('تعذر الاتصال بالخادم.'); }
  }

  Future<Fin25OtpChallenge> request(String phone) async {
    final number = normalizeYemeniPhone(phone);
    final response = await _post('v1/auth/otp/request', {'phone': number});
    final id = response['requestId'];
    if (id is! String || !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id)) {
      throw const Fin25OtpException('الخادم لم يرجع معرف تحقق صالحاً.');
    }
    final seconds = response['expiresInSeconds'];
    if (seconds is! int || seconds <= 0) {
      throw const Fin25OtpException('مدة صلاحية الرمز غير معروفة.');
    }
    return Fin25OtpChallenge(id, seconds);
  }

  /// Legacy phone-only pilot: intentionally discards the proof and does not login.
  Future<void> verify({required String requestId, required String code}) async {
    await verifyForIdentity(requestId: requestId, code: code);
  }

  /// The returned proof is secret, single use and short lived. Supply it ONLY
  /// to the configured trusted identity API; never print, cache or persist it.
  Future<String> verifyForIdentity({required String requestId,
      required String code}) async {
    final otp = AuthInputValidation.normalizeDigits(code);
    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      throw const Fin25OtpException('رمز الرسالة يجب أن يتكون من 6 أرقام إنجليزية (0-9).');
    }
    final response = await _post('v1/auth/otp/verify',
      {'requestId': requestId, 'code': otp});
    if (response['verified'] != true) {
      throw const Fin25OtpException('لم يؤكد الخادم صحة الرمز.');
    }
    final token = response['proofToken'];
    if (token is! String || !RegExp(r'^[a-fA-F0-9-]{72}$').hasMatch(token)) {
      throw const Fin25OtpException('لم يصدر الخادم إثبات هاتف صالحاً.');
    }
    return token;
  }
}
