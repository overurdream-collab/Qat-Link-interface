import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_incident_recorder.dart';

import '../theme/app_colors.dart';

/// One consistent settings surface for both customer and merchant roles.
/// Profile changes, package subscriptions and password updates must be
/// connected to a verified identity API before they are enabled.
class AccountSettingsSheet extends StatelessWidget {
  const AccountSettingsSheet({
    super.key,
    required this.accountName,
    required this.roleLabel,
    this.address,
    this.phone,
    this.onChangeTheme,
  });

  final String accountName;
  final String roleLabel;
  final String? address;
  final String? phone;
  final VoidCallback? onChangeTheme;

  static Future<void> open(
    BuildContext context, {
    required String accountName,
    required String roleLabel,
    String? address,
    String? phone,
    VoidCallback? onChangeTheme,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AccountSettingsSheet(
      accountName: accountName,
      roleLabel: roleLabel,
      address: address,
      phone: phone,
      onChangeTheme: onChangeTheme,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const pending = 'تتطلب هذه العملية اتصالاً آمنًا بحساب موثق';
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .84,
        child: ListView(
          key: const Key('account_settings_sections'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          children: [
            Text('الضبط', style: TextStyle(
              color: c.petrol, fontSize: 21, fontWeight: FontWeight.w900,
            )),
            const SizedBox(height: 9),
            _heading('بيانات الحساب', c),
            ListTile(
              key: const Key('settings_profile_name'),
              leading: Icon(Icons.badge_outlined, color: c.petrol),
              title: const Text('الاسم'),
              subtitle: Text(accountName),
            ),
            ListTile(
              key: const Key('settings_profile_address'),
              leading: Icon(Icons.location_on_outlined, color: c.petrol),
              title: const Text('العنوان'),
              subtitle: Text(address?.trim().isNotEmpty == true ? address! : 'غير متاح في هذه المعاينة'),
            ),
            ListTile(
              key: const Key('settings_profile_phone'),
              leading: Icon(Icons.phone_android_outlined, color: c.petrol),
              title: const Text('رقم الجوال'),
              subtitle: Text(phone?.trim().isNotEmpty == true ? phone! : 'لا يُعرض دون جلسة موثقة'),
            ),
            const Divider(),
            _heading('الحساب والاشتراك', c),
            ListTile(
              key: const Key('settings_change_password'),
              leading: Icon(Icons.password_rounded, color: c.petrol),
              title: const Text('تغيير كلمة المرور'),
              subtitle: const Text(pending),
              enabled: false,
            ),
            ListTile(
              key: const Key('settings_packages'),
              leading: Icon(Icons.workspace_premium_outlined, color: c.petrol),
              title: const Text('الباقات'),
              subtitle: const Text('تُعرض تفاصيل الاشتراك بعد ربط خدمة الباقات'),
              enabled: false,
            ),
            const Divider(),
            _heading('الثقة والمعلومات', c),
            ListTile(
              key: const Key('settings_privacy'),
              leading: Icon(Icons.shield_outlined, color: c.petrol),
              title: const Text('الخصوصية والأمان'),
              subtitle: const Text('لا تُعرض البيانات المالية إلا بصلاحيات وجلسة موثقة'),
            ),
            ListTile(
              key: const Key('settings_diagnostics_export'),
              leading: Icon(Icons.bug_report_outlined, color: c.petrol),
              title: const Text('تقرير الأعطال'),
              subtitle: const Text('نسخ رموز الأعطال والأوقات فقط، دون أرقام أو بيانات مالية. لا إرسال تلقائي.'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(
                  text: AppIncidentRecorder.exportSanitized(),
                ));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تم نسخ تقرير الأعطال الآمن، ويمكنك مشاركته مع الدعم.'),
                ));
              },
            ),
            ListTile(
              key: const Key('settings_about'),
              leading: Icon(Icons.info_outline, color: c.petrol),
              title: const Text('حول التطبيق'),
              subtitle: Text('مقوتي لينك — $roleLabel — معاينة تصميم مستقلة'),
            ),
            if (onChangeTheme != null)
              ListTile(
                leading: Icon(Icons.palette_outlined, color: c.petrol),
                title: const Text('تغيير المظهر'),
                onTap: () {
                  Navigator.of(context).pop();
                  onChangeTheme!();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String title, AppThemeColors c) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 13, 8, 4),
    child: Text(title, style: TextStyle(
      color: c.petrol, fontWeight: FontWeight.w900, fontSize: 13,
    )),
  );
}
