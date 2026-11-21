import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/auth_input_validation.dart';
import '../features/auth/registration_role.dart';
import '../widgets/auth/auth_brand_hero.dart';
import 'registration_screen.dart';

/// Premium login design isolated on the explicitly requested green branch.
/// UI only: credentials are NOT authenticated locally or sent to a server.
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
  static const _blue = Color(0xFF328BF5);
  static const _purple = Color(0xFF7939EA);
  static const _cyan = Color(0xFF73DCF6);
  static const _ink = Color(0xFF111A4B);
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _showPin = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _notConnected(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        '$action غير متاح حتى توصيل المصادقة الآمنة بالخادم. '
        'لا تُفتح الحسابات بمجرد تعبئة البيانات.',
      )),
    );
  }

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;
    // Do not persist credentials or grant access without server verification.
    _notConnected('تسجيل الدخول');
  }

  @override
  Widget build(BuildContext context) {
    final pink = Theme.of(context).colorScheme.primary != const Color(0xFF2E7D32) &&
        Theme.of(context).colorScheme.primary == const Color(0xFF96295F);
    final dark = widget.isDark;
    final primary = pink ? const Color(0xFFAD3379) : _purple;
    final secondary = pink ? const Color(0xFF8551B2) : _blue;
    final light = pink ? const Color(0xFFF8DCEB) : _cyan;
    final base = dark ? (pink ? const Color(0xFF251B30) : const Color(0xFF171A3C))
        : (pink ? const Color(0xFFFFEFF6) : const Color(0xFFF2F3FF));
    final text = dark ? (pink ? const Color(0xFFFFEFF7) : const Color(0xFFF3F3FF))
        : (pink ? const Color(0xFF45233D) : _ink);
    final soft = dark ? const Color(0xFFC8C6DF) : const Color(0xFF767FAE);
    final card = dark ? (pink ? const Color(0xFF34253B) : const Color(0xFF24274C))
        : const Color(0xFFF9FAFF);
    final field = dark ? const Color(0xFF313455) : Colors.white;
    final decoration = InputDecoration(
      filled: true, fillColor: field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: primary.withValues(alpha: .12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
    );

    return Scaffold(
      backgroundColor: base,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(17, 8, 17, 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: dark ? 'الوضع النهاري' : 'الوضع الليلي',
                      onPressed: widget.onToggleTheme,
                      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          color: text),
                    ),
                  ),
                  const AuthBrandHero(),
                  Transform.translate(
                    offset: const Offset(0, -5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: card.withValues(alpha: .92),
                        border: Border.all(color: Colors.white.withValues(alpha: dark ? .15 : .9), width: 1.6),
                        borderRadius: BorderRadius.circular(38),
                        boxShadow: [
                          BoxShadow(color: secondary.withValues(alpha: dark ? .22 : .19),
                            blurRadius: 34, spreadRadius: 1, offset: const Offset(0, 17)),
                          BoxShadow(color: Colors.white.withValues(alpha: dark ? .02 : .9),
                            blurRadius: 11, offset: const Offset(-4, -6)),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(22, 23, 22, 21),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('تسجيل الدخول', textAlign: TextAlign.center,
                              style: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 1),
                            Text('أدخل بيانات حسابك للمتابعة', textAlign: TextAlign.center,
                              style: TextStyle(color: soft, fontSize: 13)),
                            const SizedBox(height: 18),
                            TextFormField(
                              key: const Key('login_phone'),
                              controller: _phone, keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr, textAlign: TextAlign.right,
                              autofillHints: const [AutofillHints.telephoneNumber],
                              style: TextStyle(color: text),
                              decoration: decoration.copyWith(
                                labelText: 'رقم الجوال', hintText: '771234567',
                                labelStyle: TextStyle(color: soft),
                                prefixIcon: Padding(
                                  padding: EdgeInsets.only(left: 13, top: 13),
                                  child: Text('+967', textDirection: TextDirection.ltr,
                                    style: TextStyle(fontWeight: FontWeight.w700, color: text)),
                                ),
                                suffixIcon: Icon(Icons.phone_android_rounded, color: primary),
                              ),
                              validator: AuthInputValidation.phone,
                            ),
                            const SizedBox(height: 11),
                            TextFormField(
                              key: const Key('login_pin'),
                              controller: _pin, keyboardType: TextInputType.number,
                              maxLength: 4, obscureText: !_showPin,
                              obscuringCharacter: '●',
                              textDirection: TextDirection.ltr, textAlign: TextAlign.right,
                              style: TextStyle(color: text),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: decoration.copyWith(
                                labelText: 'رمز الدخول', hintText: '••••', counterText: '',
                                labelStyle: TextStyle(color: soft),
                                prefixIcon: IconButton(
                                  key: const Key('toggle_login_pin'),
                                  tooltip: _showPin ? 'إخفاء الرمز' : 'إظهار الرمز',
                                  onPressed: () => setState(() => _showPin = !_showPin),
                                  icon: Icon(_showPin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: primary),
                                ),
                                suffixIcon: Icon(Icons.lock_outline_rounded, color: primary),
                              ),
                              validator: AuthInputValidation.pin,
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _notConnected('استعادة رمز الدخول'),
                                  child: Text('نسيت رمز الدخول؟', style: TextStyle(color: primary, fontSize: 12)),
                                ),
                                const Spacer(),
                                Text('تذكرني', style: TextStyle(color: text, fontSize: 12)),
                                Checkbox(
                                  key: const Key('login_remember_me'),
                                  value: _rememberMe,
                                  activeColor: primary,
                                  onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [light, secondary, primary],
                                  begin: Alignment.centerLeft, end: Alignment.centerRight),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [BoxShadow(color: primary.withValues(alpha: .32),
                                  blurRadius: 17, offset: const Offset(0, 8))],
                              ),
                              child: FilledButton.icon(
                                key: const Key('login_submit'),
                                onPressed: _signIn,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                ),
                                icon: const Icon(Icons.login_rounded, color: Colors.white),
                                label: const Text('تسجيل الدخول',
                                  style: TextStyle(color: Colors.white, fontSize: 16,
                                    fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4, runSpacing: 0,
                              children: [
                                Text('ليس لديك حساب؟', style: TextStyle(color: text, fontSize: 12)),
                                TextButton.icon(
                                  key: const Key('open_registration'),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => RegistrationScreen(
                                      isDark: widget.isDark, onToggleTheme: widget.onToggleTheme,
                                      onGenderChanged: widget.onGenderChanged))),
                                  icon: Icon(Icons.person_add_alt_rounded, size: 17, color: primary),
                                  label: Text('إنشاء حساب جديد',
                                    style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Feature(icon: Icons.account_balance_wallet_outlined,
                        text: 'حسابات موثّقة', color: primary, textColor: text),
                      _Feature(icon: Icons.calendar_month_outlined,
                        text: 'حجوزات', color: primary, textColor: text),
                      _Feature(icon: Icons.notifications_none_rounded,
                        text: 'تنبيهات', color: primary, textColor: text),
                      _Feature(icon: Icons.smart_toy_outlined,
                        text: 'مساعد ذكي', color: primary, textColor: text),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('open_customer_preview'),
                    onPressed: widget.onOpenCustomerPreview,
                    icon: Icon(Icons.visibility_outlined, size: 16, color: soft),
                    label: Text('معاينة واجهات العميل',
                      style: TextStyle(fontSize: 11, color: soft)),
                  ),
                  Text('المعاملات المالية لا تُعتمد دون استيفاء الموافقات المطلوبة.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: soft)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text,
    required this.color, required this.textColor});
  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 39, height: 39,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: .15)),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(height: 4),
        Text(text, textAlign: TextAlign.center, maxLines: 2,
          style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
