import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import '../models/app_models.dart';
import 'merchant_financial_assistant_screen.dart';
import '../services/app_state.dart';
import '../services/movement_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/premium_tokens.dart';
import '../widgets/app_chrome.dart';
import '../widgets/finance_display.dart';
import '../widgets/home/premium_home_hero.dart';
import '../widgets/home/hero_carousel.dart';
import '../widgets/home/new_currency_card.dart';
import 'merchant_approval_center_screen.dart';

/// Merchant home screen body only.
/// Top icons, theme switch and bottom navigation belong to MerchantAppShell
/// and must NOT be copied into subsequent screens (including Movement).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.state,
    this.onOpenMovements,
  });

  final AppState state;
  final VoidCallback? onOpenMovements;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _currencyController = PageController(viewportFraction: .73, initialPage: 150);
  int _currencyPage = 0;

  @override
  void dispose() {
    _currencyController.dispose();
    super.dispose();
  }

  List<CurrencyCardData> _currencyData(List<MovementModel> movements) {
    final cards = <CurrencyCardData>[];
    for (final currency in CurrencyCode.values) {
      final debts = MovementCalculator.approvedDebts(
        movements, currency: currency,
      );
      final payments = MovementCalculator.approvedPayments(
        movements, currency: currency,
      );
      final pending = MovementCalculator.pendingTotal(
        movements, currency: currency,
      );
      final debtDouble = double.tryParse(debts.toString()) ?? 0;
      final paidDouble = double.tryParse(payments.toString()) ?? 0;
      final ratio = debtDouble <= 0
          ? double.nan
          : (paidDouble / debtDouble).clamp(0.0, 1.0).toDouble();
      cards.add(
        CurrencyCardData(
          currency: currency,
          debts: FinanceDisplay.amount(debts),
          balance: FinanceDisplay.amount(debts - payments),
          isCredit: (debts - payments) < Decimal.zero,
          payments: FinanceDisplay.amount(payments),
          pending: FinanceDisplay.amount(pending),
          collectionRate: ratio,
        ),
      );
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.state.movements,
        widget.state.customers,
        widget.state.relationships,
      ]),
      builder: (context, _) {
        final movements = widget.state.movements.value;
        final currencies = _currencyData(movements);
        // The merchant shell has no authenticated session yet; these are
        // visual request buckets, not permission to approve or reject.
        final pending = movements
            .where((m) => m.status == MovementStatus.pending)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final needsReview = pending
            .where((m) => m.createdByRole == ParticipantRole.customer)
            .toList();
        final waitingForClient = pending
            .where((m) => m.createdByRole == ParticipantRole.merchant)
            .toList();
        final c = context.colors;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          children: [
            const PremiumHomeHero(),
            const SizedBox(height: 12),
            const HeroCarousel(),
            const SizedBox(height: 21),
            const AppSectionTitle(title: 'أرصدة المتجر'),
            const SizedBox(height: 10),
            SizedBox(
              height: 230,
              child: PageView.builder(
                controller: _currencyController,
                itemCount: currencies.length * 101,
                onPageChanged: (index) => setState(() => _currencyPage = index % currencies.length),
                itemBuilder: (context, index) => AnimatedScale(
                  scale: _currencyPage == index % currencies.length ? 1 : .89,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: NewCurrencyCard(data: currencies[index % currencies.length]),
                ),
              ),
            ),
            const SizedBox(height: 11),
            _buildDots(c, currencies.length),
            const SizedBox(height: 24),
            const AppSectionTitle(title: 'تحتاج إلى إجراء'),
            const SizedBox(height: 10),
            if (needsReview.isEmpty)
              _emptyState('لا توجد إجراءات معلقة حالياً', c)
            else
              for (final m in needsReview.take(3)) ...[
                _actionCard(m, c),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 24),
            AppSectionTitle(
              title: 'بانتظار موافقة العملاء',
              trailing: TextButton(
                key: const Key('home_view_waiting_customer'),
                onPressed: widget.onOpenMovements,
                child: Text('عرض الحركة (${waitingForClient.length})'),
              ),
            ),
            const SizedBox(height: 10),
            if (waitingForClient.isEmpty)
              _emptyState('لا توجد طلبات معلقة', c)
            else
              AppSurface(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var i = 0; i < waitingForClient.take(3).length; i++) ...[
                      if (i > 0) Divider(color: c.cardBorder, height: 1),
                      _waitingRow(waitingForClient[i], c),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 28),
            const AppSectionTitle(title: 'الخدمات الذكية'),
            const SizedBox(height: 10),
            _assistantBanner(c),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }

  Widget _buildDots(AppThemeColors c, int count) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currencyPage == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currencyPage == i ? c.petrol : c.cardBorder,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
        ],
      );

  Widget _emptyState(String text, AppThemeColors c) => AppSurface(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(text, style: TextStyle(fontSize: 12, color: c.muted)),
        ),
      );

  String _customerName(String id) {
    for (final customer in widget.state.customers.value) {
      if (customer.id == id) return customer.name;
    }
    return 'عميل';
  }

  Widget _actionCard(MovementModel m, AppThemeColors c) => AppSurface(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: c.pale,
              child: Text(
                _customerName(m.customerId).substring(0, 1),
                style: TextStyle(color: c.petrol, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _customerName(m.customerId),
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'التاريخ: ${_date(m.createdAt)}',
                    style: TextStyle(color: c.muted, fontSize: 10),
                  ),
                  Text(
                    'نوع العملية: ${m.type == MovementType.debt ? 'إضافة دين' : 'تسديد'}',
                    style: TextStyle(color: c.muted, fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      OutlinedButton.icon(
                        key: Key('home_review_${m.id}'),
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => MerchantApprovalCenterScreen(
                              state: widget.state,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.fact_check_outlined, size: 15),
                        label: const Text('مراجعة',
                            style: TextStyle(fontSize: 10)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.petrol,
                          side: BorderSide(color: c.cardBorder),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          minimumSize: const Size(0, 30),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${FinanceDisplay.amount(m.amount)} ${FinanceDisplay.currencySymbol(m.currency)}',
                  style: TextStyle(
                    color: c.petrol,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                _pendingPill(c, 'بانتظار الموافقة'),
              ],
            ),
          ],
        ),
      );

  Widget _pendingPill(AppThemeColors c, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: c.pendingBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(
          color: c.pendingText, fontSize: 8, fontWeight: FontWeight.w800,
        )),
      );

  Widget _waitingRow(MovementModel m, AppThemeColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: c.pale,
              child: Text(_customerName(m.customerId).substring(0, 1),
                  style: TextStyle(color: c.petrol)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_customerName(m.customerId), style: TextStyle(
                    color: c.text, fontWeight: FontWeight.w800, fontSize: 12,
                  )),
                  Text(_date(m.createdAt), style: TextStyle(
                    color: c.muted, fontSize: 9,
                  )),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${FinanceDisplay.amount(m.amount)} ${FinanceDisplay.currencySymbol(m.currency)}',
                  style: TextStyle(
                    color: c.petrol, fontWeight: FontWeight.w800, fontSize: 12,
                  ),
                ),
                Text(
                  m.type == MovementType.debt ? 'دين' : 'تسديد',
                  style: TextStyle(color: c.muted, fontSize: 9),
                ),
                const SizedBox(height: 3),
                _pendingPill(c, 'معلق'),
              ],
            ),
          ],
        ),
      );

  String _date(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  Widget _assistantBanner(AppThemeColors c) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => MerchantFinancialAssistantScreen(state: widget.state),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: context.premium.hero,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: context.premium.shadow,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المساعد المالي الذكي', style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      )),
                      SizedBox(height: 4),
                      Text(
                        'افهم وضعك المالي، واتخذ قرارات أفضل، وجنّب نفسك الخسارة.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      );
}
