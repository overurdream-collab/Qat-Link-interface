import 'package:flutter/material.dart';

import '../services/fin25_otp_client.dart';
import 'fin25_otp_screen.dart';

/// Accept only an HTTPS origin: changing a temporary tunnel needs no APK build.
Uri? fin25PilotOrigin(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
      uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.host == 'localhost' || uri.host == '::1' ||
      uri.host.startsWith('127.')) {
    return null;
  }
  return uri.replace(path: '/');
}

class Fin25PilotSetupScreen extends StatefulWidget {
  const Fin25PilotSetupScreen({super.key});

  @override
  State<Fin25PilotSetupScreen> createState() => _Fin25PilotSetupScreenState();
}

class _Fin25PilotSetupScreenState extends State<Fin25PilotSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _open() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      Fin25OtpScreen(
        phone: Fin25OtpClient.normalizeYemeniPhone(_phone.text),
        baseUri: fin25PilotOrigin(_url.text)!,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مقوتي لينك — اختبار الجوال')),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Form(key: _form, child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.phonelink_lock_outlined, size: 56),
          const SizedBox(height: 16),
          const Text('تجربة رسالة التحقق على الجوال',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('انسخ عنوان HTTPS الذي نجح في تطبيق بوابة الرسائل. '
            'أدخل رقمك المخصص للاختبار. الانتقال للخطوة التالية لا يرسل رسالة.'),
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('pilot_url'), controller: _url,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url, autocorrect: false,
            decoration: const InputDecoration(labelText: 'عنوان الخادم HTTPS'),
            validator: (value) => fin25PilotOrigin(value ?? '') == null
              ? 'أدخل عنوان HTTPS الخارجي فقط دون مسار أو بيانات دخول.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('pilot_phone'), controller: _phone,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم الاختبار اليمني'),
            validator: (value) {
              try { Fin25OtpClient.normalizeYemeniPhone(value ?? ''); return null; }
              on Fin25OtpException catch (e) { return e.message; }
            },
          ),
          const SizedBox(height: 24),
          FilledButton(key: const Key('pilot_continue'), onPressed: _open,
            child: const Text('متابعة إلى اختبار الرمز')),
          const SizedBox(height: 16),
          const Text('هذه النسخة لا تفتح حساب التاجر أو العميل. '
            'نجاح الرمز يثبت ملكية الرقم فقط؛ جلسة الدخول المالية مرحلة منفصلة.',
            textAlign: TextAlign.center),
        ],
      )),
    ))),
  );
}
