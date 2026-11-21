import 'package:flutter/material.dart';
import '../widgets/auth/auth_brand_hero.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/fin25_otp_client.dart';
import '../services/identity_session_client.dart';
import 'identity_account_screen.dart';

/// FIN25 phone verification and, when configured, a real Identity session.
class Fin25OtpScreen extends StatefulWidget {
  const Fin25OtpScreen({super.key, required this.phone, required this.baseUri,
    this.httpClient, this.identityClient, this.requestedRole, this.displayName,
    this.manualRequestIdOnly = false, this.pilotAccessKey, this.identityBaseUri});
  final String phone;
  final Uri baseUri;
  /// Caller retains ownership when injecting a client (for widget tests).
  final http.Client? httpClient;
  final IdentitySessionClient? identityClient;
  final String? requestedRole;
  final String? displayName;
  /// Real Android login test: only verification, not SMS request from Android.
  final bool manualRequestIdOnly;
  final String? pilotAccessKey;
  /// Production: same configured public origin for OTP and Identity.
  final Uri? identityBaseUri;
  @override
  State<Fin25OtpScreen> createState() => _Fin25OtpScreenState();
}

class _Fin25OtpScreenState extends State<Fin25OtpScreen> {
  final _code = TextEditingController();
  final _manualId = TextEditingController();
  late final http.Client _http;
  late final Fin25OtpClient _client;
  late final IdentitySessionClient? _sessionClient;
  Fin25OtpChallenge? _challenge;
  bool _busy = false;
  bool _verified = false;
  String _message = 'رمز التحقق مكوّن من 6 أرقام ويصل برسالة SMS.';
  @override
  void initState() {
    super.initState();
    _http = widget.httpClient ?? http.Client();
    _client = Fin25OtpClient(baseUri: widget.baseUri, httpClient: _http,
      pilotAccessKey: widget.pilotAccessKey,
      usePublicRequest: widget.identityBaseUri != null);
    _sessionClient = widget.identityClient ?? (widget.identityBaseUri == null
      ? null : IdentitySessionClient(baseUri: widget.identityBaseUri!,
          httpClient: _http));
  }
  @override
  void dispose() {
    _code.dispose();
    _manualId.dispose();
    if (widget.httpClient == null) _http.close();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy || _verified) return;
    setState(() { _busy = true; _message = 'جارٍ طلب رمز التحقق...'; });
    try {
      final result = await _client.request(widget.phone);
      if (!mounted) return;
      setState(() {
        _challenge = result;
        _message = 'تم تقديم طلب الرمز للخادم. أدخل الرمز المستلم خلال ${result.expiresInSeconds ~/ 60} دقائق.';
      });
    } on Fin25OtpException catch (e) {
      if (mounted) setState(() { _message = e.message; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  void _useManualRequestId() {
    final id = _manualId.text.trim();
    if (id.length != 36 || !RegExp(r'^[0-9a-fA-F-]{36}').hasMatch(id)) {
      setState(() => _message = 'معرف الطلب غير صالح. انسخه من نتيجة طلب OTP على الكمبيوتر.');
      return;
    }
    setState(() {
      _challenge = Fin25OtpChallenge(id, 300);
      _message = 'أدخل رمز SMS الذي وصل لهاتف الاستقبال. صلاحية الرمز يحددها الخادم.';
    });
  }

  Future<void> _verify() async {
    if (_busy || _verified || _challenge == null) return;
    setState(() { _busy = true; _message = 'جارٍ التحقق من الرمز...'; });
    try {
      // FIN25 proof must be redeemed by trusted identity backend, not Flutter.
      final proof = await _client.verifyForIdentity(
        requestId: _challenge!.requestId, code: _code.text);
      if (!mounted) return;
      _code.clear();
      if (_sessionClient != null) {
        setState(() { _message = 'جارٍ إنشاء جلسة الحساب الآمنة...'; });
        try {
          final session = await _sessionClient.exchange(
            proofToken: proof,
            requestedRole: widget.requestedRole,
            displayName: widget.displayName,
          );
          if (!mounted) return;
          setState(() { _verified = true; _message = 'تم توثيق الحساب.'; });
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => IdentityAccountScreen(session: session)),
            (route) => route.isFirst,
          );
        } on IdentitySessionException catch (error) {
          if (mounted) setState(() {
            // FIN25 proof was consumed and cannot be replayed.
            _challenge = null;
            _message = '${error.message} يجب طلب رمز جديد لإعادة المحاولة.';
          });
        }
      } else {
        setState(() {
          _verified = true;
          _message = 'تم التحقق من ملكية الرقم. الدخول إلى الحساب لا يزال معطلاً حتى إصدار جلسة آمنة من خدمة الهوية.';
        });
      }
    } on Fin25OtpException catch (e) {
      if (mounted) setState(() { _message = e.message; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_sessionClient == null ? 'اختبار تحقق SMS' : 'التحقق من رقم الجوال')),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: ListView(padding: const EdgeInsets.all(22), children: [
        const MaqwatiBrandMark(height: 62),
        const SizedBox(height: 8),
        const Icon(Icons.verified_user_outlined, size: 52),
        const SizedBox(height: 12),
        Text('الرقم: ${widget.phone}', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Text(_message, textAlign: TextAlign.center,
          key: const Key('otp_status')),
        if (_challenge != null && _sessionClient == null) ...[
          const SizedBox(height: 12),
          const Text('معرّف الطلب للاختبار (لا يحتوي على الرمز):'),
          SelectableText(_challenge!.requestId,
            key: const Key('otp_request_id'), textDirection: TextDirection.ltr),
        ],
        const SizedBox(height: 20),
        if (_challenge == null && !widget.manualRequestIdOnly)
          FilledButton(key: const Key('otp_request'), onPressed: _busy ? null : _request,
            child: const Text('إرسال رمز OTP')),
        if (_challenge == null && widget.manualRequestIdOnly) ...[
          const Text('لتسجيل الدخول الحقيقي: اطلب OTP مرة واحدة من الكمبيوتر، ثم أدخل معرف الطلب هنا. هذا الإصدار لا يرسل SMS من الهاتف.'),
          TextField(key: const Key('otp_manual_request_id'),
            controller: _manualId,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'معرف طلب OTP من الكمبيوتر')),
          FilledButton(key: const Key('otp_manual_continue'),
            onPressed: _busy ? null : _useManualRequestId,
            child: const Text('متابعة للتحقق من الرمز')),
        ],
        if (_challenge != null && !_verified) ...[
          TextField(key: const Key('otp_code'), controller: _code,
            textAlign: TextAlign.center, keyboardType: TextInputType.number,
            maxLength: 6, inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              LengthLimitingTextInputFormatter(6),
            ], decoration: const InputDecoration(labelText: 'رمز الرسالة (6 أرقام)')),
          FilledButton(key: const Key('otp_verify'), onPressed: _busy ? null : _verify,
            child: const Text('تحقق من الرمز')),
        ],
        if (_busy) const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(_sessionClient == null
          ? 'التحقق من الرقم وحده لا يمنح جلسة دخول أو صلاحية مالية.'
          : 'لا تُفتح جلسة الحساب إلا بعد إثبات OTP وIdentity؛ لا صلاحيات مالية دون موافقة الطرفين.',
          textAlign: TextAlign.center),
      ]),
    ))),
  );
}
