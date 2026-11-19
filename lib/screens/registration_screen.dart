import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/auth_input_validation.dart';
import '../features/auth/registration_role.dart';
import '../services/fin25_otp_client.dart';
import 'fin25_pilot_setup_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/auth/auth_brand_hero.dart';

/// Registration form with three account types: customer / merchant / supplier.
/// This collects a draft only. No account or role is created until a trusted
/// backend verifies the number and creates the account server-side.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  RegistrationRole _selectedRole = RegistrationRole.merchant;
  bool _showPin = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // Never transmit or store a PIN. Role selection is a registration request;
    // trusted identity service issues role only after FIN25 phone proof.
    if (_selectedRole == RegistrationRole.supplier) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حساب المورد غير مدعوم حالياً في خدمة الهوية.'),
      ));
      return;
    }
    final String phone;
    try {
      phone = Fin25OtpClient.normalizeYemeniPhone(_phone.text);
    } on Fin25OtpException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Fin25PilotSetupScreen(
        initialPhone: phone,
        enableIdentity: true,
        requestedRole: _selectedRole.name,
        displayName: _name.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDarkNow = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: isDarkNow ? 'الوضع النهاري' : 'الوضع الليلي',
            onPressed: widget.onToggleTheme,
            icon: Icon(isDarkNow
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandHero(compact: true),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(color: c.cardBorder),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'اختر فئة حسابك',
                            style: TextStyle(
                              color: c.petrol,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'كل فئة لها خدمات وصلاحيات مختلفة',
                            style: TextStyle(color: c.muted, fontSize: 11),
                          ),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              for (final role in RegistrationRole.values) ...[
                                if (role != RegistrationRole.values.first)
                                  const SizedBox(width: 8),
                                Expanded(child: _roleCard(role, c)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 9),
                          Container(
                            key: const Key('role_description'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: c.pale,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: c.petrol, size: 17),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    _selectedRole.subtitle,
                                    style: TextStyle(
                                      color: c.petrol, fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 19),
                          TextFormField(
                            key: const Key('register_name'),
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الكامل',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: AuthInputValidation.fullName,
                          ),
                          const SizedBox(height: 11),
                          TextFormField(
                            key: const Key('register_phone'),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'رقم الجوال اليمني',
                              prefixText: '+967  ',
                              helperText: '9 أرقام إنجليزية فقط',
                              hintText: '771234567',
                              prefixIcon: Icon(Icons.phone_android_rounded),
                            ),
                            validator: AuthInputValidation.phone,
                          ),
                          const SizedBox(height: 11),
                          TextFormField(
                            key: const Key('register_pin'),
                            controller: _pin,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: !_showPin,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9]'),
                              ),
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: InputDecoration(
                              labelText: 'رمز الدخول (4 أرقام)',
                              counterText: '',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _showPin
                                    ? 'إخفاء الرمز'
                                    : 'إظهار الرمز',
                                onPressed: () =>
                                    setState(() => _showPin = !_showPin),
                                icon: Icon(_showPin
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                              ),
                            ),
                            validator: AuthInputValidation.pin,
                          ),
                          const SizedBox(height: 11),
                          TextFormField(
                            key: const Key('register_confirm_pin'),
                            controller: _confirmPin,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: !_showPin,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9]'),
                              ),
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'تأكيد رمز الدخول',
                              counterText: '',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                            validator: (value) =>
                                AuthInputValidation.confirmPin(
                                    value, _pin.text),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'إنشاء الحساب لا ينشئ علاقة مالية تلقائياً؛ '
                            'الارتباط والعمليات تحتاج موافقة الطرفين.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.muted, fontSize: 10, height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 13),
                          FilledButton.icon(
                            key: const Key('register_submit'),
                            onPressed: _submit,
                            icon: const Icon(Icons.person_add_alt_rounded),
                            label: const Text('متابعة للتحقق من الجوال',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('لدي حساب بالفعل — تسجيل الدخول'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard(RegistrationRole role, AppThemeColors c) {
    final selected = _selectedRole == role;
    return Material(
      color: selected ? c.pale : c.card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        key: Key('role_${role.name}'),
        onTap: () => setState(() => _selectedRole = role),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 81,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? c.petrol : c.cardBorder,
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(role.icon, size: 25,
                  color: selected ? c.petrol : c.muted),
              const SizedBox(height: 5),
              Text(
                role.title,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? c.petrol : c.text,
                  fontWeight: selected
                      ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
