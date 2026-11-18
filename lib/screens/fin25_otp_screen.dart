import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/fin25_otp_client.dart';

/// Verifies phone ownership for FIN25 testing. Does not authenticate an account.
class Fin25OtpScreen extends StatefulWidget {
  const Fin25OtpScreen({super.key, required this.phone, required this.baseUri,
    this.httpClient});
  final String phone;
  final Uri baseUri;
  /// Caller retains ownership when injecting a client (for widget tests).
  final http.Client? httpClient;
  @override
  State<Fin25OtpScreen> createState() => _Fin25OtpScreenState();
}

class _Fin25OtpScreenState extends State<Fin25OtpScreen> {
  final _code = TextEditingController();
  late final http.Client _http;
  late final Fin25OtpClient _client;
  Fin25OtpChallenge? _challenge;
  bool _busy = false;
  bool _verified = false;
  String _message = 'رمز التحقق مكوّن من 6 أرقام ويصل برسالة SMS.';
  @override
  void initState() {
    super.initState();
    _http = widget.httpClient ?? http.Client();
    _client = Fin25OtpClient(baseUri: widget.baseUri, httpClient: _http);
  }
  @override
  void dispose() {
    _code.dispose();
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

  Future<void> _verify() async {
    if (_busy || _verified || _challenge == null) return;
    setState(() { _busy = true; _message = 'جارٍ التحقق من الرمز...'; });
    try {
      await _client.verify(requestId: _challenge!.requestId, code: _code.text);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _verified = true;
        _message = 'تم التحقق من ملكية الرقم. الدخول إلى الحساب لا يزال معطلاً حتى إصدار جلسة آمنة من خدمة الهوية.';
      });
    } on Fin25OtpException catch (e) {
      if (mounted) setState(() { _message = e.message; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('اختبار تحقق SMS')),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: ListView(padding: const EdgeInsets.all(22), children: [
        const Icon(Icons.verified_user_outlined, size: 52),
        const SizedBox(height: 12),
        Text('الرقم: ${widget.phone}', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Text(_message, textAlign: TextAlign.center,
          key: const Key('otp_status')),
        if (_challenge != null) ...[
          const SizedBox(height: 12),
          const Text('معرّف الطلب للمتابعة (لا يحتوي على الرمز):'),
          SelectableText(_challenge!.requestId,
            key: const Key('otp_request_id'), textDirection: TextDirection.ltr),
        ],
        const SizedBox(height: 20),
        if (_challenge == null)
          FilledButton(key: const Key('otp_request'), onPressed: _busy ? null : _request,
            child: const Text('إرسال رمز OTP')),
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
        const Text('هذه شاشة فحص ملكية رقم الهاتف فقط. لا تمنح أي صلاحية مالية أو جلسة دخول.',
          textAlign: TextAlign.center),
      ]),
    ))),
  );
}

