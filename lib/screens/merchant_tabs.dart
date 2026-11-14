import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../services/movement_calculator.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/finance_display.dart';

/// Temporary movement body. The user's next Movement code will replace
/// this body WITHOUT touching AppTopBar, AppBottomBar, or AppTheme.
class MerchantMovementsTab extends StatefulWidget {
  const MerchantMovementsTab({super.key, required this.state});
  final AppState state;

  @override
  State<MerchantMovementsTab> createState() => _MerchantMovementsTabState();
}

class _MerchantMovementsTabState extends State<MerchantMovementsTab> {
  CurrencyCode _currency = CurrencyCode.yer;
  MovementStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: widget.state.movements,
      builder: (context, _) {
        final items = widget.state.movements.value
            .where((m) => m.currency == _currency)
            .where((m) => _filter == null || m.status == _filter)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final debts = MovementCalculator.approvedDebts(
          widget.state.movements.value, currency: _currency,
        );
        final payments = MovementCalculator.approvedPayments(
          widget.state.movements.value, currency: _currency,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
          children: [
            const AppSectionTitle(title: 'الحركة'),
            const SizedBox(height: 7),
            Text(
              'سجل الديون والتسديدات وحالة الموافقات',
              style: TextStyle(fontSize: 11, color: c.muted),
            ),
            const SizedBox(height: 16),
            _currencyChips(c, _currency, (code) => setState(() => _currency = code)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _summary(c, 'الديون المعتمدة',
                    FinanceDisplay.amount(debts))),
                const SizedBox(width: 9),
                Expanded(child: _summary(c, 'التسديدات المعتمدة',
                    FinanceDisplay.amount(payments))),
              ],
            ),
            const SizedBox(height: 17),
            Wrap(
              spacing: 7,
              children: [
                for (final item in <(MovementStatus?, String)>[
                  (null, 'الكل'),
                  (MovementStatus.approved, 'معتمد'),
                  (MovementStatus.pending, 'معلق'),
                  (MovementStatus.rejected, 'مرفوض'),
                ])
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: _filter == item.$1,
                    onSelected: (_) => setState(() => _filter = item.$1),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              AppSurface(
                child: Text(
                  'لا توجد حركات مسجلة في هذا التصنيف.',
                  style: TextStyle(color: c.muted),
                ),
              ),
            for (final item in items) ...[
              AppSurface(
                child: Row(
                  children: [
                    Icon(
                      item.type == MovementType.debt
                          ? Icons.add_circle_outline
                          : Icons.payments_outlined,
                      color: c.petrol,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.type == MovementType.debt ? 'دين' : 'تسديد',
                              style: TextStyle(color: c.text)),
                          Text(_status(item.status), style: TextStyle(
                            fontSize: 11,
                            color: item.status == MovementStatus.rejected
                                ? c.danger
                                : item.status == MovementStatus.pending
                                    ? c.pendingText
                                    : c.success,
                          )),
                        ],
                      ),
                    ),
                    Text(
                      '${FinanceDisplay.amount(item.amount)} ${FinanceDisplay.currencySymbol(item.currency)}',
                      style: TextStyle(color: c.petrol, fontWeight: FontWeight.w800),
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

  Widget _summary(AppThemeColors c, String title, String value) => AppSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: c.muted)),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(value, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: c.petrol,
          )),
        ),
      ],
    ),
  );

  String _status(MovementStatus status) => switch (status) {
    MovementStatus.approved => 'معتمد',
    MovementStatus.pending => 'معلق — لا يؤثر في الرصيد',
    MovementStatus.rejected => 'مرفوض — مستبعد',
  };
}

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
