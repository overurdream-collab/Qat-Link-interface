import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/auth_input_validation.dart';
import '../theme/app_colors.dart';
import '../widgets/auth/auth_brand_hero.dart';
import 'registration_screen.dart';
import '../services/fin25_otp_client.dart';
import 'fin25_otp_screen.dart';

/// App entry point. UI only: no PIN is persisted, sent, or accepted without
/// server authentication. Never navigate to private finance pages on form
/// validation alone.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _showPin = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _notConnected(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action غير متاح حتى توصيل المصادقة الآمنة بالخادم. '
          'لا تُفتح الحسابات بمجرد تعبئة البيانات.',
        ),
      ),
    );
  }

  // Set at build time only for a controlled FIN25 test; no server URL is hardcoded.
  static const _fin25Url = String.fromEnvironment('FIN25_OTP_BASE_URL');

  void _openOtpTest() {
    final raw = _phone.text;
    try {
      final phone = Fin25OtpClient.normalizeYemeniPhone(raw);
      final base = Uri.parse(_fin25Url);
      if (base.scheme != 'https' || base.host.isEmpty) {
        throw const FormatException('HTTPS required');
      }
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Fin25OtpScreen(phone: phone, baseUri: base),
      ));
    } on Exception {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أدخل رقماً يمنياً صحيحاً وتأكد من إعداد HTTPS للاختبار.'),
      ));
    }
  }

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;
    // Deliberately no onAuthenticated call, persistent token, local PIN
    // storage, or navigation to the financial dashboard.
    _notConnected('تسجيل الدخول');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: widget.isDark
                          ? 'الوضع النهاري'
                          : 'الوضع الليلي',
                      onPressed: widget.onToggleTheme,
                      icon: Icon(
                        widget.isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: c.petrol,
                      ),
                    ),
                  ),
                  const AuthBrandHero(),
                  const SizedBox(height: 11),
                  Container(
                    padding: const EdgeInsets.fromLTRB(19, 18, 19, 19),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: c.cardBorder),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'أهلاً بعودتك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.petrol,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'سجّل دخولك إلى حسابك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.muted, fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 17),
                          TextFormField(
                            key: const Key('login_phone'),
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            decoration: const InputDecoration(
                              labelText: 'رقم الجوال',
                              hintText: 'مثال: 771234567',
                              prefixIcon: Icon(Icons.phone_android_rounded),
                            ),
                            validator: AuthInputValidation.phone,
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            key: const Key('login_pin'),
                            controller: _pin,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: !_showPin,
                            obscuringCharacter: '●',
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9]'),
                              ),
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: InputDecoration(
                              labelText: 'رمز الدخول',
                              hintText: '••••',
                              counterText: '',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                key: const Key('toggle_login_pin'),
                                tooltip: _showPin ? 'إخفاء الرمز' : 'إظهار الرمز',
                                onPressed: () =>
                                    setState(() => _showPin = !_showPin),
                                icon: Icon(
                                  _showPin
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: AuthInputValidation.pin,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  _notConnected('استعادة رمز الدخول'),
                              child: const Text('نسيت الرمز؟'),
                            ),
                          ),
                          const SizedBox(height: 3),
                          FilledButton.icon(
                            key: const Key('login_submit'),
                            onPressed: _signIn,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('تسجيل الدخول',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                )),
                          ),
                          if (_fin25Url.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              key: const Key('fin25_otp_test'),
                              onPressed: _openOtpTest,
                              icon: const Icon(Icons.sms_outlined),
                              label: const Text('اختبار تحقق SMS (بدون تسجيل دخول)'),
                            ),
                          ],
                          const SizedBox(height: 13),
                          Text(
                            'ليس لديك حساب؟',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.muted, fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 7),
                          OutlinedButton.icon(
                            key: const Key('open_registration'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RegistrationScreen(
                                  isDark: widget.isDark,
                                  onToggleTheme: widget.onToggleTheme,
                                ),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(47),
                              foregroundColor: c.petrol,
                              side: BorderSide(color: c.mint, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.person_add_alt_rounded),
                            label: const Text('إنشاء حساب',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تسجيل أي عملية مالية لا يعني اعتمادها؛ '
                    'موافقة الطرف الآخر مطلوبة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10, color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
