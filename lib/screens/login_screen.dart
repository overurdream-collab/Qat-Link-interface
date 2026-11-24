import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/auth_input_validation.dart';
import '../theme/app_colors.dart';
import '../widgets/auth/auth_brand_hero.dart';
import 'registration_screen.dart';
import '../services/fin25_otp_client.dart';
import '../services/maqwati_api_config.dart';
import 'fin25_otp_screen.dart';
import 'notification_design_preview_screen.dart';

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

  void _signInWithSms() {
    final String phone;
    try {
      phone = Fin25OtpClient.normalizeYemeniPhone(_phone.text);
    } on Fin25OtpException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)));
      return;
    }
    // One production API and one OTP+Identity flow. Never accept a manual
    // tunnel URL or test gateway key for customer authentication.
    final origin = MaqwatiApiConfig.origin;
    if (origin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لم يُجهَّز عنوان خدمة تسجيل الدخول الآمن لهذا الإصدار.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Fin25OtpScreen(
        phone: phone, baseUri: origin, identityBaseUri: origin),
    ));
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
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(
            MaqwatiBrandAssets.loginBackground,
            key: const Key('maqwati_login_background'),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            errorBuilder: (_, __, ___) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [MaqwatiBrandColors.lightAqua, c.background,
                    MaqwatiBrandColors.deepTeal.withValues(alpha: .20)],
                ),
              ),
            ),
          )),
          Positioned.fill(child: ColoredBox(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xC713212D)
                : const Color(0x8CF1F8FA),
          )),
          SafeArea(
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
                      color: widget.isDark
                          ? c.card.withValues(alpha: .96)
                          : Colors.white.withValues(alpha: .96),
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
                          const SizedBox(height: 11),
                          Container(
                            key: const Key('bilateral_approval_message'),
                            padding: const EdgeInsets.symmetric(
                                vertical: 9, horizontal: 11),
                            decoration: BoxDecoration(
                              color: c.pale,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: MaqwatiBrandColors.gold
                                    .withValues(alpha: .55)),
                            ),
                            child: Row(children: [
                              Icon(Icons.verified_user_outlined,
                                  color: c.petrol, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                'التاجر يسجّل، والعميل يعتمد',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: c.petrol,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12),
                              )),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('login_phone'),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            decoration: const InputDecoration(
                              labelText: 'رقم الجوال اليمني',
                              prefixText: '+967  ',
                              helperText: '9 أرقام إنجليزية فقط',
                              hintText: '771234567',
                              prefixIcon: Icon(Icons.phone_android_rounded),
                            ),
                            validator: AuthInputValidation.phone,
                          ),
                          const SizedBox(height: 13),
                          FilledButton.icon(
                            key: const Key('login_with_otp'),
                            onPressed: _signInWithSms,
                            style: FilledButton.styleFrom(
                              backgroundColor: MaqwatiBrandColors.deepTeal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(54),
                              side: const BorderSide(
                                color: MaqwatiBrandColors.gold,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.sms_outlined),
                            label: const Text('الدخول برمز تحقق SMS',
                              style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(height: 8),
                          Text('تصل رسالة إلى جوالك للتحقق من ملكية الرقم',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11, color: c.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: Divider(color: c.cardBorder)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Text('الدخول بالرمز الخاص (غير مفعّل)',
                                style: TextStyle(
                                  fontSize: 11, color: c.muted,
                                )),
                            ),
                            Expanded(child: Divider(color: c.cardBorder)),
                          ]),
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
                          OutlinedButton.icon(
                            key: const Key('login_submit'),
                            onPressed: _signIn,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(45),
                              foregroundColor: c.muted,
                              side: BorderSide(color: c.cardBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.lock_clock_outlined),
                            label: const Text('الدخول بالرمز الخاص (قيد التطوير)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                          const SizedBox(height: 10),

                          if (kDebugMode) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              key: const Key('open_notification_design_preview'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const NotificationDesignPreviewScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: const Text('معاينة حركة التنبيهات والحجوزات'),
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
        ],
      ),
    );
  }
}
