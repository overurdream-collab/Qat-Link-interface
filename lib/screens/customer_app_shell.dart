import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../services/fin08_api_client.dart';
import '../services/fin14_batch_gateway.dart';
import '../services/fin15_amendment_gateway.dart';
import '../services/fin13_ledger_gateway.dart';
import '../services/fin16_credit_gateway.dart';
import '../services/movement_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/premium_tokens.dart';
import '../widgets/app_chrome.dart';
import '../widgets/account_settings_sheet.dart';
import '../widgets/home/premium_home_hero.dart';
import '../widgets/finance_display.dart';
import '../widgets/merchant_space/booking_intake_policy.dart';
import '../widgets/merchant_space/client_store_booking_sheet.dart';
import '../widgets/merchant_space/customer_store_rating_sheet.dart';
import 'fin08_customer_claims_screen.dart';
import 'fin08_customer_relationships_screen.dart';
import 'fin13_relationship_ledger_screen.dart';

/// Customer role shell. Private data is shown only when the caller supplies a
/// customer ID from a verified server session. The default constructor is a
/// safe design preview with no financial identity or data.
class CustomerAppShell extends StatefulWidget {
  const CustomerAppShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    this.customerId,
    this.verifiedSession = false,
    this.customerName = 'حساب العميل',
    this.state,
    this.claimsGateway,
    this.batchGateway,
    this.amendmentGateway,
    this.ledgerGateway,
    this.creditGateway,
    this.merchantNames = const {},
    this.publicStores = const [],
    this.studioPosts = const [],
    this.bookings = const [],
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final String? customerId;
  final bool verifiedSession;
  final String customerName;
  final AppState? state;
  final Fin08ClaimsGateway? claimsGateway;
  final Fin14BatchGateway? batchGateway;
  final Fin15AmendmentGateway? amendmentGateway;
  final Fin13LedgerGateway? ledgerGateway;
  final Fin16CreditGateway? creditGateway;
  final Map<String, String> merchantNames;
  final List<CustomerPublicStore> publicStores;
  final List<CustomerStudioPost> studioPosts;
  final List<CustomerBooking> bookings;

  @override
  State<CustomerAppShell> createState() => _CustomerAppShellState();
}

class _CustomerAppShellState extends State<CustomerAppShell> {
  late final AppState _state = widget.state ?? AppState();
  late final bool _ownsState = widget.state == null;
  int _selectedIndex = 0;

  bool get _canViewPrivateData =>
      widget.verifiedSession && (widget.customerId?.trim().isNotEmpty ?? false);

  @override
  void dispose() {
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  void _notifications() {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('التنبيهات', style: TextStyle(color: c.petrol, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(_canViewPrivateData
                ? 'ستظهر هنا تنبيهات الحساب والطلبات من الخادم عند ربط خدمة الإشعارات.'
                : 'معاينة فقط. إشعارات الحساب تتطلب تسجيل دخول موثقاً.',
                style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(height: 18),
          ]),
        ),
      ),
    );
  }

  void _settings() {
    // Show only the authenticated customer's own profile. Preview must
    // never populate the settings sheet with another customer's data.
    CustomerModel? profile;
    if (_canViewPrivateData) {
      for (final customer in _state.customers.value) {
        if (customer.id == widget.customerId) {
          profile = customer;
          break;
        }
      }
    }
    final addressValue = profile?.profileData['address'];
    AccountSettingsSheet.open(
      context,
      accountName: profile?.name ?? widget.customerName,
      roleLabel: 'العميل',
      phone: profile?.phone,
      address: addressValue is String ? addressValue : null,
      onChangeTheme: widget.onToggleTheme,
    );
  }

  Future<void> _openClaims() async {
    final gateway = widget.claimsGateway;
    if (!_canViewPrivateData || gateway == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('مراجعة الديون تتطلب حساباً موثقاً واتصالاً آمناً بالخادم.'),
      ));
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => Fin08CustomerClaimsScreen(
        gateway: gateway,
        batchGateway: widget.batchGateway,
        amendmentGateway: widget.amendmentGateway,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(children: [
          AppTopBar(
            isDark: widget.isDark,
            accountName: widget.customerName,
            onSettingsTap: _settings,
            onNotificationsTap: _notifications,
            onThemeTap: widget.onToggleTheme,
          ),
          if (!_canViewPrivateData) const _PreviewNotice(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                CustomerHomeScreen(
                  state: _state,
                  customerId: _canViewPrivateData ? widget.customerId : null,
                  merchantNames: widget.merchantNames,
                  onOpenMovements: () => setState(() => _selectedIndex = 1),
                  onOpenMerchants: () => setState(() => _selectedIndex = 3),
                  onReviewClaims: _openClaims,
                ),
                CustomerMovementsScreen(
                  state: _state,
                  customerId: _canViewPrivateData ? widget.customerId : null,
                  merchantNames: widget.merchantNames,
                  onReviewClaims: _openClaims,
                  onOpenLedger: _openRelationshipLedger,
                ),
                CustomerStudioScreen(
                  posts: widget.studioPosts,
                  bookings: widget.bookings,
                  verifiedSession: _canViewPrivateData,
                ),
                CustomerMerchantsScreen(
                  state: _state,
                  customerId: _canViewPrivateData ? widget.customerId : null,
                  merchantNames: widget.merchantNames,
                  onReviewClaims: _openClaims,
                  onReviewRelationships: widget.claimsGateway == null || !_canViewPrivateData
                      ? null
                      : () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                            builder: (_) => Fin08CustomerRelationshipsScreen(gateway: widget.claimsGateway!),
                          )),
                  onOpenMerchant: _openMerchantAccount,
                ),
                CustomerDiscoverScreen(
                  stores: widget.publicStores,
                  state: _state,
                  customerId: _canViewPrivateData ? widget.customerId : null,
                  onOpenStore: (store) => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CustomerPublicStoreDetailsScreen(
                        store: store,
                        state: _state,
                        customerId: _canViewPrivateData ? widget.customerId : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _CustomerBottomBar(
            selectedIndex: _selectedIndex,
            onSelect: (index) => setState(() => _selectedIndex = index),
          ),
        ]),
      ),
    );
  }

  void _openRelationshipLedger(String relationshipId) {
    final gateway = widget.ledgerGateway;
    final id = widget.customerId;
    if (!_canViewPrivateData || gateway == null || id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('دفتر العلاقة يتطلب جلسة موثقة واتصالاً آمناً بالخادم.'),
      ));
      return;
    }
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => Fin13RelationshipLedgerScreen(
        gateway: gateway,
        relationshipId: relationshipId,
        actorId: id,
        role: ParticipantRole.customer,
        batchGateway: widget.batchGateway,
        amendmentGateway: widget.amendmentGateway,
        creditGateway: widget.creditGateway,
      ),
    ));
  }

  void _openMerchantAccount(String merchantId) {
    final id = widget.customerId;
    final relation = _state.relationships.value.where((r) =>
      r.customerId == id && r.merchantId == merchantId &&
      r.status == RelationshipStatus.approved);
    if (relation.isEmpty) return;
    final ledger = widget.ledgerGateway;
    if (_canViewPrivateData && id != null && ledger != null) {
      _openRelationshipLedger(relation.first.id);
      return;
    }
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => CustomerMerchantAccountScreen(
        state: _state,
        customerId: id!,
        merchantId: merchantId,
        merchantName: widget.merchantNames[merchantId] ?? 'التاجر',
      ),
    ));
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.pale, borderRadius: BorderRadius.circular(11), border: Border.all(color: c.cardBorder)),
      child: Row(children: [
        Icon(Icons.visibility_outlined, size: 16, color: c.petrol),
        const SizedBox(width: 7),
        Expanded(child: Text('معاينة واجهات العميل — لا تعرض بيانات أو أرصدة حقيقية.', style: TextStyle(color: c.petrol, fontSize: 10, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _CustomerBottomBar extends StatelessWidget {
  const _CustomerBottomBar({required this.selectedIndex, required this.onSelect});
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _items = <(String, IconData)>[
    ('الرئيسية', Icons.home_outlined),
    ('الحركة', Icons.receipt_long_outlined),
    ('استديو', Icons.photo_library_outlined),
    ('التجار', Icons.storefront_outlined),
    ('اكتشف', Icons.explore_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final darkDock = Theme.of(context).brightness == Brightness.dark;
    final navInk = context.premium.ink;
    return SizedBox(
      height: 83,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            top: 10,
            child: Container(
              key: const Key('customer_green_bottom_bar'),
              decoration: BoxDecoration(
                color: context.premium.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white, width: 1.4),
                boxShadow: PremiumTokens.floatingShadow,
              ),
            ),
          ),
          // The distinct semicircular cradle is an extension of the bar.
          Positioned(
            top: 0,
            child: Container(
              width: 84,
              height: 47,
              decoration: BoxDecoration(
                color: context.premium.selected,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(46)),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
            ),
          ),
          Positioned.fill(
            top: 12,
            child: Row(children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: index == 2
                      ? const SizedBox.shrink()
                      : InkWell(
                          key: Key('customer_nav_$index'),
                          onTap: () => onSelect(index),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_items[index].$2,
                                  size: 21,
                                  color: navInk),
                              const SizedBox(height: 3),
                              Text(
                                _items[index].$1,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: index == selectedIndex
                                      ? FontWeight.w900 : FontWeight.w500,
                                  color: navInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
            ]),
          ),
          Positioned(
            top: -5,
            child: Semantics(
              label: 'استديو',
              selected: selectedIndex == 2,
              button: true,
              child: Tooltip(
                message: 'استديو',
                child: Material(
                  color: context.premium.accent,
                  elevation: 5,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('customer_nav_2'),
                    customBorder: const CircleBorder(),
                    onTap: () => onSelect(2),
                    child: const SizedBox(
                      width: 65,
                      height: 65,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_rounded,
                              size: 25, color: Colors.white),
                          Text('استديو', style: TextStyle(
                            color: Colors.white, fontSize: 10,
                            height: 1.15, fontWeight: FontWeight.w800,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({
    super.key,
    required this.state,
    required this.customerId,
    required this.merchantNames,
    required this.onOpenMovements,
    required this.onOpenMerchants,
    required this.onReviewClaims,
  });
  final AppState state;
  final String? customerId;
  final Map<String, String> merchantNames;
  final VoidCallback onOpenMovements;
  final VoidCallback onOpenMerchants;
  final VoidCallback onReviewClaims;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([state.movements, state.relationships]),
    builder: (context, _) {
      final c = context.colors;
      final id = customerId;
      final relationships = id == null ? <RelationshipModel>[] : state.relationships.value.where((r) => r.customerId == id).toList();
      final reviewCount = id == null ? 0 : state.movements.value.where((m) => m.customerId == id && m.status == MovementStatus.pending && m.createdByRole == ParticipantRole.merchant).length;
      return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
        const PremiumHomeHero(),
        const SizedBox(height: 18),
        Row(children: [
          const Expanded(child: AppSectionTitle(title: 'ملخص الحسابات')),
          Text('3 عملات مستقلة', style: TextStyle(color: c.muted, fontSize: 10)),
        ]),
        const SizedBox(height: 9),
        _CustomerCurrencyPager(state: state, customerId: id),
        const SizedBox(height: 14),
        _CustomerActionCard(
          icon: Icons.fact_check_outlined,
          title: 'تحتاج إلى مراجعتك',
          subtitle: id == null ? 'تظهر طلبات الديون بعد تسجيل الدخول الموثق.' : reviewCount == 0 ? 'لا توجد عمليات بانتظار موافقتك.' : '$reviewCount عملية بانتظار قرارك المستقل.',
          count: id == null ? null : reviewCount,
          onTap: onReviewClaims,
          keyValue: 'customer_review_claims',
        ),
        const SizedBox(height: 9),
        _CustomerActionCard(
          icon: Icons.handshake_outlined,
          title: 'طلبات ارتباط التجار',
          subtitle: id == null ? 'راجع التاجر ووافق على العلاقة بصورة مستقلة عن الديون.' : '${relationships.where((r) => r.status == RelationshipStatus.pending).length} طلب ارتباط معلق.',
          onTap: onOpenMerchants,
          keyValue: 'customer_open_merchants',
        ),
        const SizedBox(height: 16),
        AppSurface(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('كيف يظهر الرصيد؟', style: TextStyle(color: c.petrol, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 6),
          Text('لا يؤثر في الرصيد المعتمد إلا الدين أو التسديد الذي اكتملت موافقاته المطلوبة. المطالبات المعلقة والمرفوضة تظهر منفصلة.', style: TextStyle(color: c.muted, fontSize: 11, height: 1.45)),
        ])),
        const SizedBox(height: 12),
        OutlinedButton.icon(key: const Key('customer_home_movements'), onPressed: onOpenMovements, icon: const Icon(Icons.history_rounded), label: const Text('عرض سجل الحركة')),
        if (id != null) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(key: const Key('customer_home_assistant'), onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => _CustomerAccountsAssistant(state: state, customerId: id))), icon: const Icon(Icons.insights_outlined), label: const Text('مساعد حساباتي')),
        ],
        const SizedBox(height: 6),
        Text('يتم جلب بيانات الحسابات من الخادم بعد اكتمال ربط الدخول الآمن.', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 9)),
      ]);
    },
  );
}

/// Same swipeable 3-currency concept as the merchant home, keeping each
/// currency independent. No aggregation and no preview account leakage.
class _CustomerCurrencyPager extends StatefulWidget {
  const _CustomerCurrencyPager({required this.state, required this.customerId});
  final AppState state;
  final String? customerId;

  @override
  State<_CustomerCurrencyPager> createState() => _CustomerCurrencyPagerState();
}

class _CustomerCurrencyPagerState extends State<_CustomerCurrencyPager> {
  final PageController _pages = PageController(viewportFraction: .73, initialPage: 150);
  Timer? _autoSlide;
  int _active = 0;
  int _currentPage = 150;
  bool _touching = false;

  @override
  void initState() {
    super.initState();
    _autoSlide = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _touching || !_pages.hasClients || !TickerMode.of(context)) return;
      _pages.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlide?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(children: [
      Listener(
        onPointerDown: (_) => _touching = true,
        onPointerUp: (_) => _touching = false,
        onPointerCancel: (_) => _touching = false,
        child: SizedBox(
          height: 218,
          child: PageView.builder(
            key: const Key('customer_currency_pager'),
            controller: _pages,
            itemCount: CurrencyCode.values.length * 101,
            onPageChanged: (value) => setState(() {
              _currentPage = value;
              _active = value % CurrencyCode.values.length;
            }),
            itemBuilder: (context, index) => AnimatedScale(
              scale: index % CurrencyCode.values.length == _active ? 1 : .89,
              duration: const Duration(milliseconds: 260),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                child: _CustomerBalanceCard(
                  state: widget.state,
                  customerId: widget.customerId,
                  currency: CurrencyCode.values[index % CurrencyCode.values.length],
                  showcase: true,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 7),
      Row(
        key: const Key('customer_currency_indicators'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < CurrencyCode.values.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _active == i ? 19 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _active == i ? c.petrol : c.cardBorder,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ],
      ),
    ]);
  }
}

class _CustomerHero extends StatelessWidget {
  const _CustomerHero({required this.name, required this.subtitle});
  final String name;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [c.petrol, c.mint, c.cyan]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.45)),
        ])),
        const SizedBox(width: 10),
        Container(width: 49, height: 49, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: .4))), child: const Icon(Icons.person_pin_circle_outlined, color: Colors.white, size: 28)),
      ]),
    );
  }
}

class _CustomerBalanceCard extends StatelessWidget {
  const _CustomerBalanceCard({required this.state, required this.customerId, required this.currency, this.merchantId, this.showcase = false});
  final AppState state;
  final String? customerId;
  final CurrencyCode currency;
  final String? merchantId;
  final bool showcase;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([state.movements, state.relationships]),
    builder: (context, _) {
      final c = context.colors;
      final id = customerId;
      final color = switch (currency) { CurrencyCode.yer => c.petrol, CurrencyCode.sar => c.cyan, CurrencyCode.usd => c.muted };
      final customerMovements = id != null
          ? state.movements.value.where((m) =>
              m.customerId == id &&
              (merchantId == null || m.merchantId == merchantId) &&
              m.currency == currency).toList()
          : <MovementModel>[];
      final approvedRelationshipMovements = customerMovements.where((m) =>
          state.relationships.value.any((r) =>
              r.id == m.relationshipId &&
              r.status == RelationshipStatus.approved)).toList();
      final debt = id == null ? Decimal.zero : MovementCalculator.approvedDebts(approvedRelationshipMovements, customerId: id, currency: currency);
      final payment = id == null ? Decimal.zero : MovementCalculator.approvedPayments(approvedRelationshipMovements, customerId: id, currency: currency);
      final balance = debt - payment;
      // Pending claims remain visible even while the relationship itself is pending.
      final pending = id == null ? Decimal.zero : MovementCalculator.pendingTotal(customerMovements, customerId: id, currency: currency);
      if (showcase) {
        return Container(
          key: Key('customer_balance_${currency.name}'),
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: switch (currency) {
              CurrencyCode.yer => context.premium.yer,
              CurrencyCode.sar => context.premium.sar,
              CurrencyCode.usd => context.premium.usd,
            },
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: .72), width: 1.4),
            boxShadow: PremiumTokens.floatingShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  switch (currency) {
                    CurrencyCode.yer => 'الريال اليمني',
                    CurrencyCode.sar => 'الريال السعودي',
                    CurrencyCode.usd => 'الدولار الأمريكي',
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                )),
                Text(currency.name.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 18),
              Text(id == null ? 'الرصيد يتطلب تسجيل دخول موثق' : 'الرصيد المشترك المعتمد',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  id == null ? '—' : '${FinanceDisplay.amount(balance)} ${FinanceDisplay.currencySymbol(currency)}',
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              Row(children: [
                const Icon(Icons.pending_actions_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  id == null ? 'لا توجد بيانات مالية في وضع المعاينة' : 'حركات معلقة خارج الرصيد: ${FinanceDisplay.amount(pending)}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                )),
              ]),
            ],
          ),
        );
      }
      return Container(
        key: Key('customer_balance_${currency.name}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(15), border: Border.all(color: c.cardBorder)),
        child: Row(children: [
          Container(width: 37, height: 37, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.account_balance_wallet_outlined, color: color, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(currency.name.toUpperCase(), style: TextStyle(color: c.muted, fontSize: 10, fontWeight: FontWeight.w800)),
            Text(id == null ? 'يتطلب حساباً موثقاً' : 'الرصيد المشترك المعتمد', style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(id == null ? '—' : '${FinanceDisplay.amount(balance)} ${FinanceDisplay.currencySymbol(currency)}', style: TextStyle(color: c.petrol, fontWeight: FontWeight.w900, fontSize: 13)),
            if (id != null) Text('معلق: ${FinanceDisplay.amount(pending)}', style: TextStyle(color: c.pendingText, fontSize: 9)),
          ]),
        ]),
      );
    },
  );
}

class _CustomerActionCard extends StatelessWidget {
  const _CustomerActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap, required this.keyValue, this.count});
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap; final String keyValue; final int? count;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(color: c.card, borderRadius: BorderRadius.circular(15), child: InkWell(key: Key(keyValue), onTap: onTap, borderRadius: BorderRadius.circular(15), child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: c.cardBorder)), child: Row(children: [
      Icon(icon, color: c.petrol, size: 22), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.w900, fontSize: 12)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(color: c.muted, fontSize: 10))])),
      if (count != null && count! > 0) CircleAvatar(radius: 13, backgroundColor: c.pendingBackground, child: Text('$count', style: TextStyle(color: c.pendingText, fontSize: 10, fontWeight: FontWeight.w900))) else Icon(Icons.chevron_left_rounded, color: c.muted),
    ]))));
  }
}

class CustomerMovementsScreen extends StatefulWidget {
  const CustomerMovementsScreen({super.key, required this.state, required this.customerId, required this.merchantNames, required this.onReviewClaims, required this.onOpenLedger});
  final AppState state; final String? customerId; final Map<String, String> merchantNames; final VoidCallback onReviewClaims; final ValueChanged<String> onOpenLedger;
  @override
  State<CustomerMovementsScreen> createState() => _CustomerMovementsScreenState();
}

class _CustomerMovementsScreenState extends State<CustomerMovementsScreen> {
  CurrencyCode? _currency;
  MovementStatus? _status;
  MovementType? _type;
  String _query = '';

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.state.movements, widget.state.relationships]),
    builder: (context, _) {
      final c = context.colors;
      final id = widget.customerId;
      final source = id == null ? <MovementModel>[] : widget.state.movements.value.where((m) => m.customerId == id).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final rows = source.where((m) {
        final name = widget.merchantNames[m.merchantId] ?? '';
        return (_currency == null || m.currency == _currency) &&
            (_status == null || m.status == _status) &&
            (_type == null || m.type == _type) &&
            ('${name.toLowerCase()} ${m.description ?? ''} ${m.id}'.contains(_query.toLowerCase()));
      }).toList();
      final reviewRelationships = rows
          .where((m) => m.status == MovementStatus.pending &&
              m.createdByRole == ParticipantRole.merchant)
          .map((m) => m.relationshipId)
          .toSet();
      final summaryCurrencies = _currency == null ? CurrencyCode.values : [_currency!];
      return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
        const AppSectionTitle(title: 'سجل الحركة'),
        const SizedBox(height: 4),
        Text('حركات العلاقة المعتمدة والمعلقة، دون جمع العملات.', style: TextStyle(color: c.muted, fontSize: 11)),
        if (id == null) ...[
          const SizedBox(height: 12), _CustomerEmptyCard(icon: Icons.lock_outline, title: 'سجل الحساب خاص', body: 'سجّل الدخول الموثق لعرض حركات التجار المرتبطين بك.'),
        ] else ...[
          const SizedBox(height: 12),
          TextField(key: const Key('customer_movement_search'), onChanged: (v) => setState(() => _query = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث باسم التاجر أو البيان')),
          const SizedBox(height: 9),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _FilterChip(label: 'كل العملات', selected: _currency == null, onTap: () => setState(() => _currency = null)),
            for (final unit in CurrencyCode.values) _FilterChip(label: unit.name.toUpperCase(), selected: _currency == unit, onTap: () => setState(() => _currency = unit)),
          ])),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 5, children: [
            _FilterChip(label: 'كل الحالات', selected: _status == null, onTap: () => setState(() => _status = null)),
            _FilterChip(label: 'معتمدة', selected: _status == MovementStatus.approved, onTap: () => setState(() => _status = MovementStatus.approved)),
            _FilterChip(label: 'عالقة', selected: _status == MovementStatus.pending, onTap: () => setState(() => _status = MovementStatus.pending)),
            _FilterChip(label: 'مرفوضة', selected: _status == MovementStatus.rejected, onTap: () => setState(() => _status = MovementStatus.rejected)),
          ]),
          const SizedBox(height: 11),
          for (final unit in summaryCurrencies)
            Padding(padding: const EdgeInsets.only(bottom: 7), child: AppSurface(padding: const EdgeInsets.all(12), child: Column(children: [
              Align(alignment: Alignment.centerRight, child: Text(unit.name.toUpperCase(), style: TextStyle(color: c.petrol, fontWeight: FontWeight.w900, fontSize: 10))),
              _AmountSummaryRow(label: 'ديون معتمدة', value: source.where((m) => m.currency == unit && m.status == MovementStatus.approved && m.type == MovementType.debt).fold(Decimal.zero, (v, m) => v + m.amount), currency: unit),
              _AmountSummaryRow(label: 'دفعات معتمدة', value: source.where((m) => m.currency == unit && m.status == MovementStatus.approved && m.type == MovementType.payment).fold(Decimal.zero, (v, m) => v + m.amount), currency: unit),
              _AmountSummaryRow(label: 'حركات معلقة — خارج الرصيد', value: source.where((m) => m.currency == unit && m.status == MovementStatus.pending).fold(Decimal.zero, (v, m) => v + m.amount), currency: unit, highlight: true),
            ]))),
          const SizedBox(height: 14),
          Row(children: [const Expanded(child: AppSectionTitle(title: 'العمليات')), Text('${rows.length}', style: TextStyle(color: c.muted, fontSize: 10))]),
          const SizedBox(height: 8),
          if (rows.isEmpty) _CustomerEmptyCard(icon: Icons.receipt_long_outlined, title: 'لا توجد حركات مطابقة', body: 'ستظهر هنا عمليات التجار بعد ربط حسابك ومراجعة الفلاتر.'),
          for (final movement in rows) _CustomerMovementCard(movement: movement, merchantName: widget.merchantNames[movement.merchantId] ?? 'التاجر'),
          for (final relationId in reviewRelationships)
            OutlinedButton.icon(
              key: Key('customer_open_ledger_$relationId'),
              onPressed: () => widget.onOpenLedger(relationId),
              icon: const Icon(Icons.account_balance_outlined),
              label: Text('مراجعة دفتر ${widget.merchantNames[source.firstWhere((m) => m.relationshipId == relationId).merchantId] ?? 'التاجر'}'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(key: const Key('customer_open_claims_from_movements'), onPressed: widget.onReviewClaims, icon: const Icon(Icons.fact_check_outlined), label: const Text('طلبات الديون السابقة')),
          Text('الموافقة أو الرفض لا يتاحان إلا عبر الخادم الموثق.', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 9)),
        ],
      ]);
    },
  );
}

class _CustomerMovementCard extends StatelessWidget {
  const _CustomerMovementCard({required this.movement, required this.merchantName});
  final MovementModel movement; final String merchantName;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = switch (movement.status) { MovementStatus.approved => ('معتمدة', c.success), MovementStatus.pending => (movement.createdByRole == ParticipantRole.merchant ? 'تحتاج موافقتك' : 'بانتظار التاجر', c.pendingText), MovementStatus.rejected => ('مرفوضة', c.danger) };
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: AppSurface(padding: const EdgeInsets.all(12), child: Row(children: [
      CircleAvatar(radius: 19, backgroundColor: c.pale, child: Icon(movement.type == MovementType.debt ? Icons.add_card_outlined : Icons.payments_outlined, color: c.petrol, size: 19)),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(merchantName, style: TextStyle(color: c.text, fontWeight: FontWeight.w900, fontSize: 12)), Text('${movement.type == MovementType.debt ? 'دين' : 'تسديد'} • ${_dateLabel(movement.createdAt)}', style: TextStyle(color: c.muted, fontSize: 10)), if (movement.description?.isNotEmpty == true) Text(movement.description!, style: TextStyle(color: c.muted, fontSize: 10)), Text(state.$1, style: TextStyle(color: state.$2, fontSize: 10, fontWeight: FontWeight.w800))])),
      const SizedBox(width: 5),
      Text('${FinanceDisplay.amount(movement.amount)}\n${movement.currency.name.toUpperCase()}', textAlign: TextAlign.end, style: TextStyle(color: c.petrol, fontSize: 11, fontWeight: FontWeight.w900)),
    ])));
  }
}

class CustomerMerchantsScreen extends StatelessWidget {
  const CustomerMerchantsScreen({super.key, required this.state, required this.customerId, required this.merchantNames, required this.onReviewClaims, required this.onReviewRelationships, required this.onOpenMerchant});
  final AppState state; final String? customerId; final Map<String, String> merchantNames; final VoidCallback onReviewClaims; final VoidCallback? onReviewRelationships; final ValueChanged<String> onOpenMerchant;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([state.relationships, state.movements]),
    builder: (context, _) {
      final c = context.colors;
      final id = customerId;
      final relationships = id == null ? <RelationshipModel>[] : state.relationships.value.where((r) => r.customerId == id).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
        const AppSectionTitle(title: 'التجار وحساباتك'),
        const SizedBox(height: 5),
        Text('العلاقة التجارية مستقلة عن اعتماد كل دين أو دفعة.', style: TextStyle(color: c.muted, fontSize: 11)),
        if (id == null) ...[
          const SizedBox(height: 13), _CustomerEmptyCard(icon: Icons.lock_outline, title: 'قائمة التجار خاصة', body: 'تظهر علاقاتك وطلبات الارتباط بعد تسجيل الدخول الموثق.'),
        ] else ...[
          const SizedBox(height: 10),
          if (onReviewRelationships != null) OutlinedButton.icon(key: const Key('customer_review_relationships'), onPressed: onReviewRelationships, icon: const Icon(Icons.handshake_outlined), label: const Text('مراجعة طلبات الارتباط')),
          OutlinedButton.icon(key: const Key('customer_review_past_claims'), onPressed: onReviewClaims, icon: const Icon(Icons.fact_check_outlined), label: const Text('مراجعة الديون والدفعات السابقة')),
          const SizedBox(height: 12),
          if (relationships.isEmpty) _CustomerEmptyCard(icon: Icons.storefront_outlined, title: 'لا توجد علاقات تجارية بعد', body: 'المتاجر التي تزورها في «اكتشف» لا تنشئ علاقة مالية تلقائياً.'),
          for (final relation in relationships) _RelationshipCard(relation: relation, merchantName: merchantNames[relation.merchantId] ?? 'التاجر', onOpen: relation.status == RelationshipStatus.approved ? () => onOpenMerchant(relation.merchantId) : null),
        ],
      ]);
    },
  );
}

class _RelationshipCard extends StatelessWidget {
  const _RelationshipCard({required this.relation, required this.merchantName, this.onOpen});
  final RelationshipModel relation; final String merchantName; final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (relation.status) { RelationshipStatus.approved => ('علاقة معتمدة', c.success), RelationshipStatus.pending => ('بانتظار قرارك أو قرار التاجر', c.pendingText), RelationshipStatus.rejected => ('علاقة مرفوضة', c.danger), RelationshipStatus.cancelled => ('علاقة ملغاة', c.muted), RelationshipStatus.suspended => ('علاقة موقوفة', c.danger) };
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: AppSurface(key: Key('customer_relation_${relation.id}'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [CircleAvatar(backgroundColor: c.pale, child: Icon(Icons.storefront_outlined, color: c.petrol)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(merchantName, style: TextStyle(color: c.text, fontWeight: FontWeight.w900)), Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800))]))]),
      if (onOpen != null) ...[const SizedBox(height: 9), OutlinedButton(onPressed: onOpen, child: const Text('عرض الحساب المشترك'))],
      if (relation.status == RelationshipStatus.pending) Padding(padding: const EdgeInsets.only(top: 7), child: Text('قبول العلاقة لا يعني اعتماد أي عملية مالية.', style: TextStyle(color: c.muted, fontSize: 10))),
    ])));
  }
}

class CustomerMerchantAccountScreen extends StatelessWidget {
  const CustomerMerchantAccountScreen({super.key, required this.state, required this.customerId, required this.merchantId, required this.merchantName});
  final AppState state; final String customerId; final String merchantId; final String merchantName;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(merchantName)),
    body: AnimatedBuilder(animation: Listenable.merge([state.movements, state.relationships]), builder: (context, _) {
      final c = context.colors;
      final matching = state.relationships.value.where((r) => r.customerId == customerId && r.merchantId == merchantId && r.status == RelationshipStatus.approved);
      final relation = matching.isEmpty ? null : matching.first;
      if (relation == null) return const _CustomerEmptyCard(icon: Icons.lock_outline, title: 'الحساب غير متاح', body: 'لا يوجد ارتباط معتمد ونشط لهذا الحساب.');
      final rows = state.movements.value.where((m) => m.relationshipId == relation.id).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ListView(padding: const EdgeInsets.all(14), children: [
        Text('الرصيد المشترك حسب العملة', style: TextStyle(color: c.petrol, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final currency in CurrencyCode.values) _CustomerBalanceCard(state: state, customerId: customerId, merchantId: merchantId, currency: currency),
        const SizedBox(height: 9),
        for (final row in rows) _CustomerMovementCard(movement: row, merchantName: merchantName),
        if (rows.isEmpty) const _CustomerEmptyCard(icon: Icons.receipt_long_outlined, title: 'لا توجد عمليات', body: 'ستظهر العمليات بعد تسجيلها من أحد الطرفين.'),
      ]);
    }),
  );
}

class CustomerPublicStore {
  const CustomerPublicStore({required this.merchantId, required this.name, required this.governorate, required this.market, required this.isOpen, required this.acceptsBookings, this.description = '', this.imageUrl, this.bookingSettings});
  final String merchantId; final String name; final String governorate; final String market; final bool isOpen; final bool acceptsBookings; final String description; final String? imageUrl;
  final BookingIntakeSettings? bookingSettings;
}

class CustomerDiscoverScreen extends StatefulWidget {
  const CustomerDiscoverScreen({super.key, required this.stores, required this.state, required this.customerId, required this.onOpenStore});
  final List<CustomerPublicStore> stores;
  final AppState state;
  final String? customerId;
  final ValueChanged<CustomerPublicStore> onOpenStore;
  @override
  State<CustomerDiscoverScreen> createState() => _CustomerDiscoverScreenState();
}

class _CustomerDiscoverScreenState extends State<CustomerDiscoverScreen> {
  String? _governorate; String _market = ''; bool? _openOnly; bool? _bookingOnly; String _search = '';
  static const _governorates = ['أمانة العاصمة', 'صنعاء', 'عدن', 'تعز', 'إب', 'ذمار', 'الحديدة', 'حجة', 'عمران', 'صعدة', 'مأرب', 'حضرموت'];
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final markets = widget.stores.where((s) => _governorate == null || s.governorate == _governorate).map((s) => s.market).toSet().toList()..sort();
    final stores = widget.stores.where((s) => (_governorate == null || s.governorate == _governorate) && (_market.isEmpty || s.market == _market) && (_openOnly != true || s.isOpen) && (_bookingOnly != true || s.acceptsBookings) && ('${s.name} ${s.market} ${s.governorate}'.toLowerCase().contains(_search.toLowerCase()))).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
      const AppSectionTitle(title: 'استكشف المتاجر العاملة الآن'),
      const SizedBox(height: 4),
      Text('اختر المحافظة ثم السوق. زيارة المتجر لا تنشئ علاقة مالية.', style: TextStyle(color: c.muted, fontSize: 11)),
      const SizedBox(height: 10),
      TextField(key: const Key('customer_discover_search'), onChanged: (v) => setState(() => _search = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن متجر أو سوق')),
      const SizedBox(height: 9),
      DropdownButtonFormField<String>(key: const Key('customer_discover_governorate'), value: _governorate, isExpanded: true, decoration: const InputDecoration(labelText: 'المحافظة', prefixIcon: Icon(Icons.place_outlined)), items: [const DropdownMenuItem(value: null, child: Text('كل المحافظات')), for (final g in _governorates) DropdownMenuItem(value: g, child: Text(g))], onChanged: (v) => setState(() { _governorate = v; _market = ''; })),
      const SizedBox(height: 7),
      DropdownButtonFormField<String>(key: const Key('customer_discover_market'), value: _market.isEmpty ? null : _market, isExpanded: true, decoration: const InputDecoration(labelText: 'السوق', prefixIcon: Icon(Icons.store_mall_directory_outlined)), items: [const DropdownMenuItem(value: null, child: Text('كل الأسواق')), for (final m in markets) DropdownMenuItem(value: m, child: Text(m))], onChanged: markets.isEmpty ? null : (v) => setState(() => _market = v ?? '')),
      const SizedBox(height: 8),
      Wrap(spacing: 7, runSpacing: 5, children: [
        _FilterChip(label: 'كل الحالات', selected: _openOnly == null, onTap: () => setState(() => _openOnly = null)),
        _FilterChip(label: 'مفتوح', selected: _openOnly == true, onTap: () => setState(() => _openOnly = true)),
        _FilterChip(label: 'يستقبل حجوزات', selected: _bookingOnly == true, onTap: () => setState(() => _bookingOnly = _bookingOnly == true ? null : true)),
      ]),
      const SizedBox(height: 12),
      if (stores.isEmpty) _CustomerEmptyCard(icon: Icons.explore_outlined, title: 'لا توجد متاجر للعرض الآن', body: widget.stores.isEmpty ? 'قائمة المتاجر العامة ستظهر عند ربط دليل المتاجر بالخادم.' : 'جرّب تغيير المحافظة أو السوق أو الفلاتر.'),
      for (final store in stores) _PublicStoreCard(store: store, onTap: () => widget.onOpenStore(store)),
      const SizedBox(height: 8),
      Text('المتجر المغلق قد يستقبل حجوزات إذا كان هذا الخيار مفعلاً لديه.', style: TextStyle(color: c.muted, fontSize: 10)),
    ]);
  }
}

class _PublicStoreCard extends StatelessWidget {
  const _PublicStoreCard({required this.store, required this.onTap}); final CustomerPublicStore store; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(padding: const EdgeInsets.only(bottom: 9), child: AppSurface(key: Key('public_store_${store.merchantId}'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [CircleAvatar(backgroundColor: c.pale, child: Icon(Icons.storefront_outlined, color: c.petrol)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.name, style: TextStyle(color: c.text, fontWeight: FontWeight.w900)), Text('${store.governorate} • ${store.market}', style: TextStyle(color: c.muted, fontSize: 10))]))]),
      if (store.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 7), child: Text(store.description, style: TextStyle(color: c.muted, fontSize: 11))),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: [
        _StatusTag(text: store.isOpen ? 'مفتوح' : 'مغلق', active: store.isOpen),
        _StatusTag(text: store.acceptsBookings ? 'يستقبل حجوزات' : 'لا يستقبل حجوزات', active: store.acceptsBookings),
      ]),
      const SizedBox(height: 8),
      OutlinedButton(key: Key('public_store_view_${store.merchantId}'), onPressed: onTap, child: const Text('عرض تفاصيل المتجر')),
    ])));
  }
}

class CustomerPublicStoreDetailsScreen extends StatelessWidget {
  const CustomerPublicStoreDetailsScreen({super.key, required this.store, required this.state, required this.customerId});
  final CustomerPublicStore store;
  final AppState state;
  final String? customerId;

  Future<void> _book(BuildContext context) async {
    final id = customerId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('للحجز، سجّل الدخول بحساب عميل موثق.'),
      ));
      return;
    }
    final settings = store.bookingSettings;
    if (!store.acceptsBookings || settings == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.card,
      builder: (_) => ClientStoreBookingSheet(
        merchantId: store.merchantId,
        customerId: id,
        intakeSettings: settings,
        customers: state.customers.value,
        relationships: state.relationships.value,
        // Booking remains disabled until an authenticated server callback is wired.
      ),
    );
  }

  Future<void> _rate(BuildContext context) async {
    final id = customerId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('التقييم متاح بعد تسجيل الدخول بحساب موثق.'),
      ));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.card,
      builder: (_) => CustomerStoreRatingSheet(
        merchantId: store.merchantId,
        customerId: id,
        customers: state.customers.value,
        relationships: state.relationships.value,
        movements: state.movements.value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(store.name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(height: 170, decoration: BoxDecoration(color: c.pale, borderRadius: BorderRadius.circular(18)), child: Icon(Icons.storefront_outlined, color: c.petrol, size: 52)),
        const SizedBox(height: 13),
        Text(store.name, style: TextStyle(color: c.text, fontWeight: FontWeight.w900, fontSize: 19)),
        const SizedBox(height: 4),
        Text('${store.governorate} • ${store.market}', style: TextStyle(color: c.muted, fontSize: 11)),
        if (store.description.isNotEmpty) ...[const SizedBox(height: 10), Text(store.description, style: TextStyle(color: c.muted, fontSize: 12, height: 1.5))],
        const SizedBox(height: 12),
        Wrap(spacing: 7, children: [
          _StatusTag(text: store.isOpen ? 'مفتوح' : 'مغلق', active: store.isOpen),
          _StatusTag(text: store.acceptsBookings ? 'يستقبل حجوزات' : 'لا يستقبل حجوزات', active: store.acceptsBookings),
        ]),
        const SizedBox(height: 16),
        if (store.acceptsBookings)
          FilledButton.icon(key: const Key('customer_store_book'), onPressed: store.bookingSettings == null ? null : () => _book(context), icon: const Icon(Icons.event_available_outlined), label: Text(store.bookingSettings == null ? 'بيانات الحجز غير متاحة الآن' : 'طلب حجز')),
        OutlinedButton.icon(key: const Key('customer_store_rate'), onPressed: () => _rate(context), icon: const Icon(Icons.star_outline_rounded), label: const Text('تقييم المتجر')),
        const SizedBox(height: 8),
        Text('حالة فتح المتجر واستقباله للحجوزات إعدادان مستقلان. زيارة المتجر أو الحجز لا تنشئ ديناً أو علاقة مالية.', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 10, height: 1.4)),
      ]),
    );
  }
}

class CustomerStudioPost {
  const CustomerStudioPost({required this.id, required this.merchantId, required this.merchantName, required this.caption, required this.createdAt, this.mediaUrl, this.isVideo = false, this.isFavorite = false, this.isLiked = false});
  final String id; final String merchantId; final String merchantName; final String caption; final DateTime createdAt; final String? mediaUrl; final bool isVideo; final bool isFavorite; final bool isLiked;
}

class CustomerBooking {
  const CustomerBooking({required this.id, required this.merchantName, required this.description, required this.createdAt, required this.status});
  final String id; final String merchantName; final String description; final DateTime createdAt; final String status;
}

class CustomerStudioScreen extends StatefulWidget {
  const CustomerStudioScreen({super.key, required this.posts, required this.bookings, required this.verifiedSession});
  final List<CustomerStudioPost> posts; final List<CustomerBooking> bookings; final bool verifiedSession;
  @override
  State<CustomerStudioScreen> createState() => _CustomerStudioScreenState();
}

class _CustomerStudioScreenState extends State<CustomerStudioScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
      const AppSectionTitle(title: 'استوديو التجار'),
      const SizedBox(height: 4),
      Text('صور وفيديوهات المتاجر العامة والتجار المرتبطين بك.', style: TextStyle(color: c.muted, fontSize: 11)),
      const SizedBox(height: 10),
      SegmentedButton<int>(key: const Key('customer_studio_tabs'), segments: const [ButtonSegment(value: 0, label: Text('المحتوى'), icon: Icon(Icons.photo_library_outlined)), ButtonSegment(value: 1, label: Text('حجوزاتي'), icon: Icon(Icons.event_note_outlined))], selected: {_tab}, onSelectionChanged: (values) => setState(() => _tab = values.first)),
      const SizedBox(height: 11),
      if (_tab == 0) ...[
        if (widget.posts.isEmpty) _CustomerEmptyCard(icon: Icons.perm_media_outlined, title: 'لا يوجد محتوى متاح حالياً', body: 'سيظهر محتوى التجار بعد ربط الاستوديو بدليل المتاجر والصلاحيات.'),
        for (final post in widget.posts) _StudioPostCard(post: post),
      ] else ...[
        if (!widget.verifiedSession) _CustomerEmptyCard(icon: Icons.lock_outline, title: 'حجوزاتك خاصة', body: 'تسجيل الدخول الموثق مطلوب لعرض حجوزاتك.'),
        if (widget.verifiedSession && widget.bookings.isEmpty) _CustomerEmptyCard(icon: Icons.event_busy_outlined, title: 'لا توجد حجوزات', body: 'حجوزاتك لدى المتاجر ستظهر هنا بعد ربط خدمة الحجوزات.'),
        if (widget.verifiedSession) for (final booking in widget.bookings) _BookingCard(booking: booking),
      ],
    ]);
  }
}

class _StudioPostCard extends StatelessWidget {
  const _StudioPostCard({required this.post}); final CustomerStudioPost post;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: AppSurface(key: Key('customer_studio_post_${post.id}'), padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(height: 150, decoration: BoxDecoration(color: c.pale, borderRadius: const BorderRadius.vertical(top: Radius.circular(14))), child: Icon(post.isVideo ? Icons.play_circle_outline_rounded : Icons.image_outlined, size: 42, color: c.petrol)),
      Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(post.merchantName, style: TextStyle(color: c.petrol, fontWeight: FontWeight.w900, fontSize: 12)),
        const SizedBox(height: 4), Text(post.caption, style: TextStyle(color: c.text, fontSize: 11)),
        const SizedBox(height: 8), Row(children: [
          IconButton(tooltip: 'إعجاب', onPressed: null, icon: Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, color: c.danger)),
          IconButton(tooltip: 'مفضلة', onPressed: null, icon: Icon(post.isFavorite ? Icons.bookmark : Icons.bookmark_border, color: c.petrol)),
          IconButton(tooltip: 'مشاركة', onPressed: null, icon: Icon(Icons.share_outlined, color: c.muted)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'التفاعل يتطلب ربط الحساب بالخادم',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(color: c.muted, fontSize: 9),
            ),
          ),
        ]),
      ])),
    ])));
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking}); final CustomerBooking booking;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: AppSurface(key: Key('customer_booking_${booking.id}'), child: Row(children: [
      Icon(Icons.event_available_outlined, color: c.petrol), const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(booking.merchantName, style: TextStyle(color: c.text, fontWeight: FontWeight.w900)), Text(booking.description, style: TextStyle(color: c.muted, fontSize: 10)), Text('${_dateLabel(booking.createdAt)} • ${booking.status}', style: TextStyle(color: c.pendingText, fontSize: 10, fontWeight: FontWeight.w700))])),
    ])));
  }
}

class _CustomerAccountsAssistant extends StatelessWidget {
  const _CustomerAccountsAssistant({required this.state, required this.customerId}); final AppState state; final String customerId;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('مساعد حساباتي')), body: AnimatedBuilder(animation: Listenable.merge([state.movements, state.relationships]), builder: (context, _) {
    final c = context.colors;
    final customerMovements = state.movements.value.where((m) => m.customerId == customerId && state.relationships.value.any((r) => r.id == m.relationshipId && r.status == RelationshipStatus.approved)).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _CustomerHero(name: 'ملخص حساباتك', subtitle: 'تحليل حسابي مبسط حسب العملة. لا يجمع العملات.'),
      const SizedBox(height: 14),
      for (final currency in CurrencyCode.values) ...[
        _CustomerBalanceCard(state: state, customerId: customerId, currency: currency),
        Padding(padding: const EdgeInsets.only(bottom: 8), child: AppSurface(child: Text('معتمدة: ${FinanceDisplay.amount(MovementCalculator.approvedDebts(customerMovements, customerId: customerId, currency: currency))} ديون • ${FinanceDisplay.amount(MovementCalculator.approvedPayments(customerMovements, customerId: customerId, currency: currency))} دفعات', style: TextStyle(color: c.muted, fontSize: 10)))),
      ],
      const SizedBox(height: 6),
      Text('هذا الملخص حسابي من الحركات المتاحة، وليس نصيحة ائتمانية أو قراراً آلياً.', style: TextStyle(color: c.muted, fontSize: 10)),
    ]);
  }));
}

class _CustomerEmptyCard extends StatelessWidget {
  const _CustomerEmptyCard({required this.icon, required this.title, required this.body}); final IconData icon; final String title; final String body;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppSurface(padding: const EdgeInsets.all(21), child: Column(children: [Icon(icon, color: c.muted, size: 31), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: TextStyle(color: c.text, fontWeight: FontWeight.w900, fontSize: 13)), const SizedBox(height: 5), Text(body, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 11, height: 1.4))]));
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap}); final String label; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(padding: const EdgeInsetsDirectional.only(end: 5), child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap(), selectedColor: c.pale, labelStyle: TextStyle(color: selected ? c.petrol : c.muted, fontSize: 10, fontWeight: selected ? FontWeight.w800 : FontWeight.w500), side: BorderSide(color: selected ? c.mint : c.cardBorder)));
  }
}

class _AmountSummaryRow extends StatelessWidget {
  const _AmountSummaryRow({required this.label, required this.value, required this.currency, this.highlight = false}); final String label; final Decimal value; final CurrencyCode? currency; final bool highlight;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amount = currency == null ? '${FinanceDisplay.amount(value)} — افصل العملة' : '${FinanceDisplay.amount(value)} ${FinanceDisplay.currencySymbol(currency!)}';
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: highlight ? c.pendingText : c.muted, fontSize: 10))), Text(amount, style: TextStyle(color: highlight ? c.pendingText : c.text, fontWeight: FontWeight.w900, fontSize: 10))]));
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text, required this.active}); final String text; final bool active;
  @override
  Widget build(BuildContext context) { final c = context.colors; return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: active ? c.pale : c.pendingBackground, borderRadius: BorderRadius.circular(8)), child: Text(text, style: TextStyle(color: active ? c.petrol : c.pendingText, fontSize: 9, fontWeight: FontWeight.w800))); }
}

String _dateLabel(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
