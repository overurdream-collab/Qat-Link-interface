import 'package:flutter/material.dart';
import '../widgets/auth/auth_brand_hero.dart';
import '../services/identity_session_client.dart';
import 'verified_fin08_overview_screen.dart';

/// Account session confirmation. Do not expose AppState's mock financial ledger.
class IdentityAccountScreen extends StatelessWidget {
  const IdentityAccountScreen({super.key, required this.session});
  final IdentitySession session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مقوتي لينك — حساب موثّق')),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const AuthBrandHero(compact: true),
        const SizedBox(height: 8),
        const Icon(Icons.verified_user, size: 68),
        const SizedBox(height: 16),
        Text('تم تسجيل الدخول بنجاح', textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text('نوع الحساب: ${session.role == 'merchant' ? 'تاجر' : 'عميل'}',
          textAlign: TextAlign.center),
        if (session.displayName != null)
          Text(session.displayName!, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        const Text('تسجيل الدخول مؤكد من خدمة الهوية. '
          'يمكن الاطلاع على بيانات المطالبات والارتباطات من FIN08 للقراءة فقط عند توفر الربط الآمن. '
          'الدفتر المالي الكامل ولوحات البيانات التجريبية غير مفعّلة لهذا الحساب.',
          textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('open_verified_fin08_overview'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VerifiedFin08OverviewScreen(session: session))),
          icon: const Icon(Icons.cloud_done_outlined),
          label: const Text('عرض بيانات حسابي الحقيقية'),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('identity_logout'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
        ),
      ]),
    ))),
  );
}
