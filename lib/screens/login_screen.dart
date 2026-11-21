import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/auth_input_validation.dart';
import '../features/auth/registration_role.dart';
import '../theme/app_colors.dart';
import '../theme/premium_tokens.dart';
import '../widgets/auth/auth_brand_hero.dart';
import 'registration_screen.dart';

/// App entry point. UI only: no PIN is persisted, sent, or accepted without
/// server authentication. Never navigate to private finance pages on form
/// validation alone.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onGenderChanged,
    required this.onOpenCustomerPreview,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final ValueChanged<ProfileGender> onGenderChanged;
  final VoidCallback onOpenCustomerPreview;

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

  void _supportUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(
        'قناة خدمة العملاء لم تُربط بعد. سيظهر رقم التواصل المعتمد بعد تفعيله.',
      )),
    );
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
      backgroundColor: context.colors.background,
      body: Container(
        decoration: BoxDecoration(gradient: context.premium.canvas),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
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
                      color: context.premium.surface,
                      borderRadius: BorderRadius.circular(38),
                      border: Border.all(color: context.premium.outline, width: 1.5),
                      boxShadow: [BoxShadow(color: context.premium.shadow, blurRadius: 26,
                        offset: const Offset(0, 12))],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'تسجيل الدخول',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.premium.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'أدخل رقم جوالك ورمز الدخول للمتابعة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.premium.muted, fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 22),
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
                                RegExp(r'[0-9٠-٩۰-۹]'),
                              ),
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور (رمز الدخول)',
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
                          const SizedBox(height: 12),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: context.premium.action,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: PremiumTokens.floatingShadow,
                            ),
                            child: FilledButton.icon(
                            key: const Key('login_submit'),
                            onPressed: _signIn,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('تسجيل الدخول',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                )),
                            ),
                          ),
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
                                  onGenderChanged: widget.onGenderChanged,
                                ),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(47),
                              foregroundColor: context.premium.accent,
                              side: BorderSide(color: context.premium.accent, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.person_add_alt_rounded),
                            label: const Text('إنشاء حساب',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(height: 7),
                          TextButton.icon(
                            key: const Key('open_customer_preview'),
                            onPressed: widget.onOpenCustomerPreview,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('معاينة واجهات العميل'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      key: const Key('login_customer_support'),
                      onPressed: _supportUnavailable,
                      icon: Icon(Icons.headset_mic_outlined, color: context.premium.accent),
                      label: Text('خدمة العملاء', style: TextStyle(color: context.premium.accent)),
                    ),
                  ),
                  Center(
                    child: Text('جميع الحقوق محفوظة لشركة GiC ©',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: context.premium.muted)),
                  ),
                  const SizedBox(height: 10),
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
      ),
    );
  }
}
