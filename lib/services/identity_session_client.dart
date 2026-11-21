import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class IdentitySessionException implements Exception {
  const IdentitySessionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class IdentitySession {
  const IdentitySession({required this.accessToken, required this.id,
      required this.role, this.displayName});
  final String accessToken;
  final String id;
  final String role;
  final String? displayName;
}

/// Identity API origin is build-configured, NOT user-editable.
/// This is not the FIN25 OTP transport endpoint.
class IdentitySessionClient {
  IdentitySessionClient({required this.baseUri, required this.httpClient,
      this.timeout = const Duration(seconds: 12), this.pilotAccessKey}) {
    if (baseUri.scheme != 'https' || baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty || baseUri.hasQuery || baseUri.hasFragment ||
        (baseUri.path.isNotEmpty && baseUri.path != '/') ||
        baseUri.host == 'localhost' || baseUri.host.startsWith('127.')) {
      throw ArgumentError('Trusted identity HTTPS origin required');
    }
  }
  final Uri baseUri;
  final http.Client httpClient;
  final Duration timeout;
  /// Optional ephemeral test-only gateway authorization secret (memory only).
  final String? pilotAccessKey;

  static IdentitySessionClient? fromBuildConfig(http.Client client) {
    const url = String.fromEnvironment('IDENTITY_API_BASE_URL');
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    try { return IdentitySessionClient(baseUri: uri, httpClient: client); }
    on ArgumentError { return null; }
  }

  Future<IdentitySession> exchange({required String proofToken,
      String? requestedRole, String? displayName}) async {
    if (requestedRole != null && requestedRole != 'merchant' &&
        requestedRole != 'customer') {
      throw const IdentitySessionException('هذا النوع من الحسابات غير متاح حالياً.');
    }
    if (!RegExp(r'^[a-fA-F0-9-]{72}$').hasMatch(proofToken)) {
      throw const IdentitySessionException('إثبات الهاتف غير صالح.');
    }
    Map<String, dynamic> payload;
    try {
      final response = await httpClient.post(
        baseUri.resolve('v1/identity/session'),
        headers: {'content-type':'application/json','accept':'application/json',
          if (pilotAccessKey != null) 'x-pilot-key': pilotAccessKey!},
        body: jsonEncode({
          'proofToken': proofToken,
          if (requestedRole != null) 'requestedRole': requestedRole,
          if (displayName != null) 'displayName': displayName.trim(),
        }),
      ).timeout(timeout);
      if (response.statusCode != 200) {
        throw IdentitySessionException(response.statusCode == 409
            ? 'الحساب مرتبط بدور آخر، أو يلزم إنشاء الحساب أولاً. أعد طلب رمز تحقق جديد.'
            : 'تعذّر إنشاء الجلسة. قد يلزم طلب رمز تحقق جديد.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const IdentitySessionException('رد الهوية غير صالح.');
      }
      payload = decoded;
    } on IdentitySessionException { rethrow; }
      on TimeoutException {
        throw const IdentitySessionException('انتهت المهلة. لا تكرر استخدام نفس الرمز.');
      } on FormatException {
        throw const IdentitySessionException('رد الهوية غير مفهوم.');
      } on http.ClientException {
        throw const IdentitySessionException('تعذر الاتصال بخدمة الهوية.');
      }

    final access = payload['accessToken'];
    final account = payload['account'];
    if (access is! String || access.length < 50 ||
        account is! Map<String, dynamic> ||
        account['id'] is! String ||
        !['merchant','customer'].contains(account['role']) ||
        payload['expiresInSeconds'] is! int ||
        payload['expiresInSeconds'] <= 0 || payload['expiresInSeconds'] > 900) {
      throw const IdentitySessionException('الجلسة المستلمة غير صالحة.');
    }
    // Confirm the issuer recognises this session and account.
    try {
      final response = await httpClient.get(
        baseUri.resolve('v1/identity/me'),
        headers: {'authorization':'Bearer $access','accept':'application/json',
          if (pilotAccessKey != null) 'x-pilot-key': pilotAccessKey!},
      ).timeout(timeout);
      if (response.statusCode != 200) {
        throw const IdentitySessionException('تعذر تأكيد جلسة الدخول.');
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['account'] is! Map<String, dynamic> ||
          body['account']['id'] != account['id'] ||
          body['account']['role'] != account['role']) {
        throw const IdentitySessionException('هوية الجلسة غير متطابقة.');
      }
    } on IdentitySessionException { rethrow; }
      on TimeoutException {
        throw const IdentitySessionException('انتهت مهلة تأكيد جلسة الدخول.');
      } on FormatException {
        throw const IdentitySessionException('رد تأكيد الهوية غير مفهوم.');
      } on http.ClientException {
        throw const IdentitySessionException('تعذر تأكيد اتصال الهوية.');
      }
    return IdentitySession(accessToken:access,id:account['id'] as String,
      role:account['role'] as String,displayName:account['displayName'] as String?);
  }
}
