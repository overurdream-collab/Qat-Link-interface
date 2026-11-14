import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../services/movement_calculator.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/finance_display.dart';

export 'movement_screen.dart' show MerchantMovementsTab;

/// Customers are sorted by highest approved net debt for the selected
/// currency; balances are never added across currencies.
class MerchantCustomersTab extends StatefulWidget {
  const MerchantCustomersTab({super.key, required this.state});
  final AppState state;

  @override
  State<MerchantCustomersTab> createState() => _MerchantCustomersTabState();
}

class _MerchantCustomersTabState extends State<MerchantCustomersTab> {
  CurrencyCode _currency = CurrencyCode.yer;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.state.customers,
        widget.state.movements,
      ]),
      builder: (context, _) {
        final customers = widget.state.customers.value
            .where((customer) =>
                customer.name.contains(_query.trim()) ||
                customer.phone.contains(_query.trim()))
            .toList()
          ..sort((a, b) {
            final left = MovementCalculator.customerBalance(
              widget.state.movements.value,
              customerId: a.id,
              currency: _currency,
            );
            final right = MovementCalculator.customerBalance(
              widget.state.movements.value,
              customerId: b.id,
              currency: _currency,
            );
            return right.compareTo(left);
          });
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
          children: [
            const AppSectionTitle(title: 'العملاء'),
            const SizedBox(height: 7),
            Text('أرصدة كل عملة منفصلة — الأعلى مديونية أولاً',
                style: TextStyle(fontSize: 11, color: c.muted)),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'البحث بالاسم أو رقم الهاتف',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 13),
            _currencyChips(c, _currency,
                (currency) => setState(() => _currency = currency)),
            const SizedBox(height: 13),
            if (customers.isEmpty)
              AppSurface(
                child: Text('لا توجد حسابات عملاء محملة.',
                  style: TextStyle(color: c.muted)),
              ),
            for (final customer in customers) ...[
              AppSurface(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: c.pale,
                      child: Icon(Icons.person_outline, color: c.petrol),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name, style: TextStyle(
                          color: c.text, fontWeight: FontWeight.w700,
                        )),
                        Text(customer.phone, style: TextStyle(
                          color: c.muted, fontSize: 11,
                        )),
                      ],
                    )),
                    Text(
                      '${FinanceDisplay.amount(MovementCalculator.customerBalance(
                        widget.state.movements.value,
                        customerId: customer.id,
                        currency: _currency,
                      ))} ${FinanceDisplay.currencySymbol(_currency)}',
                      style: TextStyle(
                        color: c.petrol, fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

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

Widget _currencyChips(
  AppThemeColors c,
  CurrencyCode selected,
  ValueChanged<CurrencyCode> onSelected,
) => Row(
  children: [
    for (final currency in CurrencyCode.values)
      Expanded(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: ChoiceChip(
            selected: currency == selected,
            onSelected: (_) => onSelected(currency),
            label: SizedBox(
              width: double.infinity,
              child: Text(
                FinanceDisplay.currencyCode(currency),
                textAlign: TextAlign.center,
              ),
            ),
            showCheckmark: false,
            selectedColor: c.pale,
            backgroundColor: c.card,
            side: BorderSide(color: c.cardBorder),
          ),
        ),
      ),
  ],
);
