import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/auth_input_validation.dart';
import '../features/auth/registration_role.dart';
import '../theme/app_colors.dart';
import '../theme/premium_tokens.dart';
import '../widgets/auth/auth_brand_hero.dart';
import '../widgets/auth/login_feature_highlights.dart';
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
    this.onOpenMerchantPreview,
    this.showPreviewLinks = false,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final ValueChanged<ProfileGender> onGenderChanged;
  final VoidCallback onOpenCustomerPreview;

  /// Visual preview only, no authenticated identity or private account.
  final VoidCallback? onOpenMerchantPreview;

  /// Hide QA-only links on the phone-facing visual APK.
  final bool showPreviewLinks;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      const SnackBar(
          content: Text(
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

  InputDecoration _inputDecoration(BuildContext context) {
    final c = context.colors;
    final border = Color.alphaBlend(
        c.muted.withValues(alpha: widget.isDark ? .6 : .8), c.card);
    OutlineInputBorder outline(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: color));
    return InputDecoration(
      filled: true,
      fillColor: c.card,
      enabledBorder: outline(border),
      border: outline(border),
      focusedBorder: outline(c.petrol),
      errorBorder: outline(c.danger),
      focusedErrorBorder: outline(c.danger),
      labelStyle: TextStyle(color: c.muted),
      floatingLabelStyle: TextStyle(color: c.link),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compact = MediaQuery.sizeOf(context).height < 860;
    return Scaffold(
      backgroundColor: c.background,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Container(
          key: const Key('approved_glass_login_frame'),
          decoration: BoxDecoration(
            color: context.premium.surface,
            borderRadius: BorderRadius.circular(43),
            border: Border.all(
              color: context.premium.outline,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: context.premium.shadow,
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: Container(
              decoration: BoxDecoration(gradient: context.premium.canvas),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(
                        child: SizedBox(
                          height: 90,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _ApprovedLoginWavesPainter(
                              pink: Theme.of(context).scaffoldBackgroundColor ==
                                      const Color(0xFFFFEFF6) ||
                                  Theme.of(context).scaffoldBackgroundColor ==
                                      const Color(0xFF251B30),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 18,
                          compact ? 6 : 12,
                          compact ? 12 : 18,
                          compact ? 24 : 26),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LayoutBuilder(builder: (context, constraints) {
                                final heroWidth =
                                    constraints.maxWidth + (compact ? 24 : 36);
                                final heroHeight =
                                    (heroWidth * .69).clamp(210.0, 270.0);
                                return SizedBox(
                                    height: heroHeight,
                                    child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(
                                              child: OverflowBox(
                                            minWidth: heroWidth,
                                            maxWidth: heroWidth,
                                            minHeight: heroHeight,
                                            maxHeight: heroHeight,
                                            child: AuthBrandHero(
                                                displayHeight: heroHeight,
                                                artFraction: .53,
                                                referenceStyle: true),
                                          )),
                                          Positioned(
                                              top: 20,
                                              left: 0,
                                              right: 0,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                        color: context
                                                            .premium.surface,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(27),
                                                        border: Border.all(
                                                            color: context
                                                                .premium
                                                                .outline)),
                                                    child:
                                                        DropdownButtonHideUnderline(
                                                            child:
                                                                DropdownButton<
                                                                    String>(
                                                      key: const Key(
                                                          'login_language'),
                                                      value: 'ar',
                                                      isDense: true,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 12),
                                                      iconSize: 18,
                                                      icon: Icon(
                                                          Icons
                                                              .keyboard_arrow_down_rounded,
                                                          color: context
                                                              .premium.accent),
                                                      style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          color: context
                                                              .premium.ink,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w800),
                                                      items: const [
                                                        DropdownMenuItem(
                                                            value: 'ar',
                                                            child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .language_rounded,
                                                                      size: 19),
                                                                  SizedBox(
                                                                      width: 7),
                                                                  Text(
                                                                      'العربية')
                                                                ]))
                                                      ],
                                                      onChanged: (_) {},
                                                    )),
                                                  ),
                                                  IconButton(
                                                    tooltip: widget.isDark
                                                        ? 'الوضع النهاري'
                                                        : 'الوضع الليلي',
                                                    onPressed:
                                                        widget.onToggleTheme,
                                                    icon: Icon(
                                                      widget.isDark
                                                          ? Icons
                                                              .light_mode_outlined
                                                          : Icons
                                                              .dark_mode_outlined,
                                                      color: c.petrol,
                                                    ),
                                                  ),
                                                ],
                                              )),
                                        ]));
                              }),
                              SizedBox(height: compact ? 0 : 3),
                              Container(
                                padding: EdgeInsets.fromLTRB(
                                    compact ? 13 : 19,
                                    compact ? 12 : 18,
                                    compact ? 13 : 19,
                                    compact ? 10 : 19),
                                decoration: BoxDecoration(
                                  color: context.premium.surface,
                                  borderRadius: BorderRadius.circular(38),
                                  border: Border.all(
                                      color: context.premium.outline,
                                      width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                        color: context.premium.shadow,
                                        blurRadius: 26,
                                        offset: const Offset(0, 12))
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'تسجيل الدخول',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: context.premium.ink,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'أدخل بيانات حسابك للمتابعة',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: context.premium.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(height: compact ? 10 : 22),
                                      TextFormField(
                                        key: const Key('login_phone'),
                                        controller: _phone,
                                        autovalidateMode:
                                            AutovalidateMode.onUserInteraction,
                                        keyboardType: TextInputType.phone,
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.right,
                                        autofillHints: const [
                                          AutofillHints.telephoneNumber
                                        ],
                                        decoration:
                                            _inputDecoration(context).copyWith(
                                          labelText: 'رقم الجوال',
                                          hintText: '771234567',
                                          prefixIcon:
                                              Icon(Icons.phone_android_rounded),
                                          suffixIcon: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                textDirection:
                                                    TextDirection.ltr,
                                                children: [
                                                  Text('+967',
                                                      textDirection:
                                                          TextDirection.ltr,
                                                      key: const Key(
                                                          'login_country_code'),
                                                      style: TextStyle(
                                                          color: context
                                                              .premium.ink,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w800)),
                                                  const SizedBox(width: 10),
                                                  Container(
                                                      width: 1,
                                                      height: 24,
                                                      color: context
                                                          .premium.outline)
                                                ]),
                                          ),
                                        ),
                                        validator: AuthInputValidation.phone,
                                      ),
                                      SizedBox(height: compact ? 8 : 13),
                                      TextFormField(
                                        key: const Key('login_pin'),
                                        controller: _pin,
                                        autovalidateMode:
                                            AutovalidateMode.onUserInteraction,
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
                                        decoration:
                                            _inputDecoration(context).copyWith(
                                          labelText: 'رمز الدخول',
                                          hintText: '••••',
                                          counterText: '',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                          ),
                                          suffixIcon: IconButton(
                                            key: const Key('toggle_login_pin'),
                                            tooltip: _showPin
                                                ? 'إخفاء الرمز'
                                                : 'إظهار الرمز',
                                            onPressed: () => setState(
                                                () => _showPin = !_showPin),
                                            icon: Icon(
                                              _showPin
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                            ),
                                          ),
                                        ),
                                        validator: AuthInputValidation.pin,
                                      ),
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        children: [
                                          MergeSemantics(
                                              child: InkWell(
                                                  onTap: () => setState(() =>
                                                      _rememberMe =
                                                          !_rememberMe),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Checkbox(
                                                          key: const Key(
                                                              'login_remember_me'),
                                                          value: _rememberMe,
                                                          activeColor: context
                                                              .premium.accent,
                                                          onChanged: (value) =>
                                                              setState(() =>
                                                                  _rememberMe =
                                                                      value ??
                                                                          false),
                                                        ),
                                                        Text('تذكرني',
                                                            style: TextStyle(
                                                                color: context
                                                                    .premium
                                                                    .ink,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                      ]))),
                                          TextButton(
                                            key: const Key(
                                                'login_forgot_password'),
                                            onPressed: () => _notConnected(
                                                'استعادة رمز الدخول'),
                                            child:
                                                const Text('نسيت رمز الدخول؟'),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: compact ? 6 : 12),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient:
                                              context.premium.accessibleAction,
                                          borderRadius:
                                              BorderRadius.circular(32),
                                          boxShadow: [
                                            BoxShadow(
                                              color: context.premium.shadow,
                                              blurRadius: 22,
                                              offset: const Offset(0, 10),
                                            )
                                          ],
                                        ),
                                        child: FilledButton.icon(
                                          key: const Key('login_submit'),
                                          onPressed: _signIn,
                                          style: FilledButton.styleFrom(
                                            minimumSize:
                                                const Size.fromHeight(54),
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32),
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
                                      SizedBox(height: compact ? 6 : 13),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 4,
                                        children: [
                                          Text('ليس لديك حساب؟',
                                              style: TextStyle(
                                                  color: c.muted,
                                                  fontSize: 12)),
                                          TextButton.icon(
                                            key: const Key('open_registration'),
                                            onPressed: () => Navigator.of(
                                                    context)
                                                .push(MaterialPageRoute<void>(
                                                    builder: (_) => RegistrationScreen(
                                                        isDark: widget.isDark,
                                                        onToggleTheme:
                                                            widget
                                                                .onToggleTheme,
                                                        onGenderChanged: widget
                                                            .onGenderChanged))),
                                            iconAlignment: IconAlignment.end,
                                            icon: const Icon(
                                                Icons.chevron_left_rounded),
                                            label: const Text('إنشاء حساب جديد',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                          ),
                                        ],
                                      ),
                                      if (widget.showPreviewLinks) ...[
                                        const SizedBox(height: 7),
                                        Material(
                                          color: Colors.transparent,
                                          child: ExpansionTile(
                                            title: Text(
                                              'معاينة الواجهات التجريبية',
                                              style: TextStyle(
                                                color: context.premium.muted,
                                                fontSize: 11,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            tilePadding: EdgeInsets.zero,
                                            childrenPadding: EdgeInsets.zero,
                                            children: [
                                              TextButton.icon(
                                                key: const Key(
                                                    'open_customer_preview'),
                                                onPressed: widget
                                                    .onOpenCustomerPreview,
                                                icon: const Icon(
                                                    Icons.visibility_outlined),
                                                label: const Text(
                                                    'معاينة واجهات العميل'),
                                              ),
                                              if (widget
                                                      .onOpenMerchantPreview !=
                                                  null)
                                                TextButton.icon(
                                                  key: const Key(
                                                      'open_merchant_preview'),
                                                  onPressed: widget
                                                      .onOpenMerchantPreview,
                                                  icon: const Icon(Icons
                                                      .storefront_outlined),
                                                  label: const Text(
                                                      'معاينة واجهات التاجر'),
                                                ),
                                              Text(
                                                'المعاينة تجريبية فقط؛ لا تسمح بالدخول إلى الحسابات أو اعتماد المبالغ.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        context.premium.muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 5 : 16),
                              Center(
                                child: TextButton.icon(
                                  key: const Key('login_customer_support'),
                                  onPressed: _supportUnavailable,
                                  icon: Icon(Icons.headset_mic_outlined,
                                      color: context.premium.accent),
                                  label: Text('خدمة العملاء',
                                      style: TextStyle(
                                          color: context.premium.accent)),
                                ),
                              ),
                              SizedBox(height: compact ? 5 : 14),
                              const LoginFeatureHighlights(),
                              SizedBox(height: compact ? 9 : 20),
                              Center(
                                child: Text('جميع الحقوق محفوظة لشركة GiC ©',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.premium.muted)),
                              ),
                            ],
                          ),
                        ),
                      ),
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

/// Decoration only: the two blue-lilac waves on the approved login reference.
/// Isolated from the interactive fields and from all financial state.
class _ApprovedLoginWavesPainter extends CustomPainter {
  const _ApprovedLoginWavesPainter({required this.pink});
  final bool pink;

  @override
  void paint(Canvas canvas, Size size) {
    final back = Path()
      ..moveTo(0, size.height * .27)
      ..cubicTo(size.width * .24, -size.height * .12, size.width * .38,
          size.height * 1.10, size.width * .67, size.height * .52)
      ..cubicTo(size.width * .83, size.height * .11, size.width * .94,
          size.height * .14, size.width, size.height * .37)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final front = Path()
      ..moveTo(0, size.height * .72)
      ..cubicTo(size.width * .23, size.height * .35, size.width * .36,
          size.height * 1.28, size.width * .56, size.height * .80)
      ..cubicTo(size.width * .79, size.height * .21, size.width * .89,
          size.height * .61, size.width, size.height * .57)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      back,
      Paint()
        ..shader = LinearGradient(
          colors: pink
              ? const [Color(0xFFEDB2E2), Color(0xFFCD9DF5), Color(0xFFF5C6E1)]
              : const [Color(0xFFBA8CF5), Color(0xFF8F80F6), Color(0xFF82CBFF)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      front,
      Paint()
        ..shader = LinearGradient(
          colors: pink
              ? const [Color(0xFFCBA1FB), Color(0xFFDE9DDE), Color(0xFFE9B7F5)]
              : const [Color(0xFFE1B6FB), Color(0xFFA279F9), Color(0xFF70CAFA)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _ApprovedLoginWavesPainter oldDelegate) =>
      pink != oldDelegate.pink;
}
