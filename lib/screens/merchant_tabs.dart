import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

export 'movement_screen.dart' show MerchantMovementsTab;
export 'customers_screen.dart' show MerchantCustomersTab;

/// MerchantSpaceTab remains unchanged; headers and bottom navigation
/// are centrally owned by MerchantAppShell.
class MerchantSpaceTab extends StatelessWidget {
  const MerchantSpaceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      children: [
        const AppSectionTitle(title: 'مساحتي'),
        const SizedBox(height: 7),
        Text('مساحة التاجر الخاصة', style: TextStyle(
          fontSize: 11, color: c.muted,
        )),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.yer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_outline_rounded, color: Colors.white, size: 35),
              SizedBox(height: 10),
              Text('حساب التاجر', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19,
              )),
              SizedBox(height: 5),
              Text('البيانات الشخصية ومتجري والعروض والخدمات',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppSurface(
          child: Column(
            children: [
              _row(c, Icons.storefront_outlined, 'متجري'),
              Divider(color: c.cardBorder),
              _row(c, Icons.person_outline_rounded, 'بياناتي الشخصية'),
              Divider(color: c.cardBorder),
              _row(c, Icons.privacy_tip_outlined, 'الخصوصية والصلاحيات'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('تحتاج هذه الأقسام إلى ربط الخدمات المعتمدة.',
            style: TextStyle(color: c.muted, fontSize: 10)),
      ],
    );
  }

  Widget _row(AppThemeColors c, IconData icon, String text) => Row(
    children: [
      Icon(icon, color: c.petrol),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(color: c.text))),
      Icon(Icons.chevron_left_rounded, color: c.muted),
    ],
  );
}

