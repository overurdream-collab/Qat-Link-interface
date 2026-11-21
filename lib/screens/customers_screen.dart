import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../models/merchant_pending_models.dart';
import '../services/app_state.dart';
import 'customer_details_screen.dart';
import 'merchant_pending_contact_details_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/customers/customers_view_model.dart';
import '../widgets/customers/merchant_debt_status_summary.dart';
import '../widgets/finance_display.dart';
import '../widgets/movement/movement_view_model.dart';
import '../widgets/customers/customer_invitation_sheet.dart';

/// The approved customers page body. The fixed top bar and bottom bar are
/// owned by MerchantAppShell, not duplicated here.
///
/// Customer profiles alone are NOT merchant relationships. Cards display
/// ONLY customers with approved relationships. A pending invitation lives
/// in a separate request section and never creates an opening balance.
class MerchantCustomersTab extends StatefulWidget {
  const MerchantCustomersTab({
    super.key,
    required this.state,
    this.merchantId,
    this.onCustomerTap,
    this.verifiedCustomerMatches = const [],
    this.verifiedClaimDecisions = const [],
    this.verifiedTransferredClaimIds = const <String>{},
  });

  final AppState state;

  /// Must be resolved from an authenticated server-side session in production.
  final String? merchantId;

  /// Server-verified proof of account/contact match; do not infer via phone.
  final List<VerifiedCustomerContactMatch> verifiedCustomerMatches;
  final List<VerifiedCustomerClaimDecision> verifiedClaimDecisions;
  final Set<String> verifiedTransferredClaimIds;

  /// Lets MerchantAppShell retain the shared top/bottom navigation.
  final void Function(CustomerModel customer, CurrencyCode currency)? onCustomerTap;

  @override
  State<MerchantCustomersTab> createState() => _MerchantCustomersTabState();
}

class _MerchantCustomersTabState extends State<MerchantCustomersTab> {
  final TextEditingController _searchController = TextEditingController();
  CurrencyCode? _currency = CurrencyCode.yer;
  CustomerListFilter _filter = CustomerListFilter.all;
  CustomerSort _sort = CustomerSort.highestDebt;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.state.customers,
        widget.state.relationships,
        widget.state.movements,
        widget.state.merchantContacts,
        widget.state.merchantPendingDebts,
        widget.state.merchantPendingPayments,
      ]),
      builder: (context, _) {
        final customers = widget.state.customers.value;
        final rels = widget.state.relationships.value;
        final movements = widget.state.movements.value;
        final metricRows = CustomersViewModel.rows(
          customers: customers,
          relationships: rels,
          movements: movements,
          merchantId: widget.merchantId,
          currency: _currency,
        );
        final visible = CustomersViewModel.rows(
          customers: customers,
          relationships: rels,
          movements: movements,
          merchantId: widget.merchantId,
          currency: _currency,
          filter: _filter,
          sort: _sort,
          search: _searchController.text,
        );
        final statusTotals = MerchantDebtStatusQuery.summarize(
          merchantId: widget.merchantId,
          contacts: widget.state.merchantContacts.value,
          privateClaims: widget.state.merchantPendingDebts.value,
          relationships: rels,
          movements: movements,
          verifiedCustomerMatches: widget.verifiedCustomerMatches,
          verifiedClaimDecisions: widget.verifiedClaimDecisions,
          verifiedTransferredClaimIds: widget.verifiedTransferredClaimIds,
        );
        final pending = CustomersViewModel.pendingRelationships(
          rels, merchantId: widget.merchantId,
        );
        final searchedMerchantContacts = widget.state.merchantContacts.value.where(
          (contact) => widget.merchantId != null &&
              contact.merchantId == widget.merchantId &&
              (MovementQuery.normalizeSearch(contact.name)
                   .contains(MovementQuery.normalizeSearch(_searchController.text)) ||
               MovementQuery.normalizeSearch(contact.phone)
                   .contains(MovementQuery.normalizeSearch(_searchController.text)))
        ).toList();
        final merchantContacts = searchedMerchantContacts.where((contact) =>
          _matchesPendingContactFilter(
            contact,
            widget.state.merchantPendingDebts.value,
            widget.state.merchantPendingPayments.value,
          )).toList();
        final customerMap = {for (final customer in customers) customer.id: customer};
        final grouped = <CurrencyCode, List<CustomerCurrencyRow>>{};
        for (final entry in visible) {
          grouped.putIfAbsent(entry.currency, () => []).add(entry);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
          children: [
            Row(
              children: [
                Container(
                  height: 37,
                  width: 37,
                  decoration: BoxDecoration(
                    color: c.pale,
                    border: Border.all(color: c.cardBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.groups_rounded, color: c.petrol, size: 22),
                ),
                const SizedBox(width: 9),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('العملاء', style: TextStyle(
                      fontWeight: FontWeight.w900, color: c.text, fontSize: 18)),
                    Text('مقوتي لينك • العلاقات المعتمدة',
                      style: TextStyle(color: c.muted, fontSize: 10)),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 47,
              child: FilledButton.icon(
                key: const Key('customers_add'),
                onPressed: _openRequestModal,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.petrol,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('إضافة عميل جديد', style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 14,
                )),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('customers_search'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: TextStyle(color: c.text, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'البحث باسم العميل أو رقم الهاتف...',
                hintStyle: TextStyle(color: c.muted, fontSize: 11),
                prefixIcon: Icon(Icons.search_rounded,
                    color: c.muted, size: 19),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () => setState(_searchController.clear),
                        icon: Icon(Icons.cancel_outlined,
                          color: c.muted, size: 18),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _metrics(
              c,
              metricRows,
              privateContactCount: merchantContacts.length,
              privateDebtorCount: merchantContacts.where((contact) =>
                _pendingContactNet(
                  contact,
                  widget.state.merchantPendingDebts.value,
                  widget.state.merchantPendingPayments.value,
                ) > Decimal.zero).length,
              privateOperationCount: widget.state.merchantPendingDebts.value
                  .where((row) => merchantContacts.any((contact) =>
                    row.contactId == contact.id && row.merchantId == widget.merchantId &&
                    (_currency == null || row.currency == _currency)))
                  .length + widget.state.merchantPendingPayments.value
                  .where((row) => merchantContacts.any((contact) =>
                    row.contactId == contact.id && row.merchantId == widget.merchantId &&
                    (_currency == null || row.currency == _currency)))
                  .length,
            ),
            const SizedBox(height: 18),
            Row(
              key: const Key('customers_compact_filters'),
              children: [
                Expanded(child: _currencyDropdown(c)),
                const SizedBox(width: 9),
                Expanded(child: _statusDropdown(c)),
              ],
            ),
            if (merchantContacts.isNotEmpty) ...[
              const SizedBox(height: 17),
              Row(children: [
                Expanded(child: Text('عملاء غير منضمين إلى التطبيق',
                  style: TextStyle(color: c.petrol, fontSize: 13,
                    fontWeight: FontWeight.w900))),
                _countBadge(c, merchantContacts.length),
              ]),
              const SizedBox(height: 5),
              Text('يمكن تسجيل ديون معلقة قبل تحميل العميل التطبيق. '
                  'هذه المبالغ من سجل التاجر وحده ولا تدخل الرصيد المعتمد.',
                style: TextStyle(color: c.muted, fontSize: 11)),
              const SizedBox(height: 9),
              for (final contact in merchantContacts) ...[
                _merchantPendingCard(c, contact),
                const SizedBox(height: 8),
              ],
            ],
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 17),
              Row(children: [
                Text('طلبات ارتباط معلقة', style: TextStyle(
                  color: c.petrol,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
                const SizedBox(width: 8),
                _countBadge(c, pending.length),
              ]),
              const SizedBox(height: 7),
              for (final request in pending) ...[
                _pendingRelationshipCard(
                  c,
                  request,
                  customerMap[request.customerId],
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 17),
            Row(
              children: [
                Text('قائمة العملاء', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900,
                  color: c.text,
                )),
                const SizedBox(width: 8),
                _countBadge(
                  c,
                  CustomersViewModel.distinctCustomers(visible) +
                      merchantContacts.length,
                ),
                const Spacer(),
                _sortPicker(c),
              ],
            ),
            const SizedBox(height: 9),
            if (_currency == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'العملات منفصلة؛ يُعرض العميل في كل عملة لها حركة مستقلة.',
                  style: TextStyle(color: c.muted, fontSize: 10),
                ),
              ),
            if (visible.isEmpty)
              _emptyState(c)
            else
              for (final group in grouped.entries) ...[
                if (_currency == null) ...[
                  _groupTitle(c, group.key),
                  const SizedBox(height: 7),
                ],
                for (final row in group.value) ...[
                  _customerCard(c, row),
                  const SizedBox(height: 10),
                ],
              ],
            const SizedBox(height: 14),
            _threeDebtStages(c, statusTotals),
          ],
        );
      },
    );
  }

  Widget _threeDebtStages(AppThemeColors c,
      Map<CurrencyCode, MerchantDebtStatusTotals> totals) {
    final currencies = _currency == null
        ? CurrencyCode.values
        : [_currency!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('الأرصدة حسب حالة العميل', style: TextStyle(
          color: c.petrol, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('لا يُجمع رصيد خارج التطبيق أو طلب موافقة مع الرصيد المعتمد. '
            'تُعرض العملات منفصلة.',
          style: TextStyle(color: c.muted, fontSize: 10)),
        const SizedBox(height: 8),
        for (final currency in currencies) ...[
          if (_currency == null)
            Padding(
              padding: const EdgeInsets.only(top: 7, bottom: 5),
              child: Text(FinanceDisplay.currencyCode(currency),
                style: TextStyle(color: c.petrol,
                  fontWeight: FontWeight.w900, fontSize: 12))),
          _stageBalanceRow(c, currency, totals[currency]),
        ],
      ],
    );
  }

  Widget _stageBalanceRow(AppThemeColors c, CurrencyCode currency,
      MerchantDebtStatusTotals? totals) {
    final outside = totals?.outsideApp ?? Decimal.zero;
    final awaiting = totals?.awaitingCustomerApproval ?? Decimal.zero;
    final approved = totals?.approvedNet ?? Decimal.zero;
    return Column(children: [
      _stageLine(c,
        key: Key('balance_outside_app_${currency.name}'),
        title: 'ديون مسجلة — بانتظار انضمام العميل',
        hint: 'عملاء خارج التطبيق؛ راجع صافيهم في ملف العميل',
        amount: outside, currency: currency, color: c.pendingText),
      const SizedBox(height: 5),
      _stageLine(c,
        key: Key('balance_awaiting_approval_${currency.name}'),
        title: 'ديون مسجلة — بانتظار موافقة العميل',
        hint: 'الديون المعلقة بعد الارتباط',
        amount: awaiting, currency: currency, color: c.pendingText),
      const SizedBox(height: 5),
      _stageLine(c,
        key: Key('balance_approved_${currency.name}'),
        title: 'الرصيد المعتمد',
        hint: 'صافي الديون ناقص التسديدات المعتمدة',
        amount: approved, currency: currency, color: c.petrol),
    ]);
  }

  Widget _stageLine(AppThemeColors c, {
    required Key key,
    required String title,
    required String hint,
    required Decimal amount,
    required CurrencyCode currency,
    required Color color,
  }) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: c.card, borderRadius: BorderRadius.circular(11),
      border: Border.all(color: c.cardBorder)),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w900)),
          Text(hint, style: TextStyle(color: c.muted, fontSize: 9)),
        ],
      )),
      Text('${FinanceDisplay.amount(amount)} '
          '${FinanceDisplay.currencyCode(currency)}',
        style: TextStyle(color: color,
          fontSize: 13, fontWeight: FontWeight.w900)),
    ]),
  );

  Widget _merchantPendingCard(
      AppThemeColors c, MerchantPendingContact contact) {
    final debtSums = <CurrencyCode, Decimal>{};
    final paymentSums = <CurrencyCode, Decimal>{};
    var debtCount = 0;
    var paymentCount = 0;
    for (final claim in widget.state.merchantPendingDebts.value) {
      if (claim.contactId != contact.id ||
          claim.merchantId != widget.merchantId) continue;
      debtCount++;
      debtSums.update(claim.currency, (old) => old + claim.amount,
          ifAbsent: () => claim.amount);
    }
    for (final payment in widget.state.merchantPendingPayments.value) {
      if (payment.contactId != contact.id ||
          payment.merchantId != widget.merchantId) continue;
      paymentCount++;
      paymentSums.update(payment.currency, (old) => old + payment.amount,
          ifAbsent: () => payment.amount);
    }
    return Container(
      key: Key('merchant_pending_contact_${contact.id}'),
      decoration: BoxDecoration(
        color: c.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.cardBorder),
      ),
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.hourglass_empty_rounded, color: c.pendingText, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.name, style: TextStyle(
                color: c.text, fontWeight: FontWeight.w900)),
              Text(contact.phone, textDirection: TextDirection.ltr,
                style: TextStyle(color: c.muted, fontSize: 11)),
            ],
          )),
          Text('بانتظار الانضمام', style: TextStyle(
            color: c.pendingText, fontSize: 11,
            fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 9),
        Text('ديون مسجلة: $debtCount • دفعات مسجلة: $paymentCount', style: TextStyle(
          color: c.pendingText, fontWeight: FontWeight.w800, fontSize: 12)),
        for (final currency in CurrencyCode.values)
          if (debtSums[currency] != null || paymentSums[currency] != null)
            Text('ديون ${FinanceDisplay.amount(debtSums[currency] ?? Decimal.zero)} '
                '− دفعات ${FinanceDisplay.amount(paymentSums[currency] ?? Decimal.zero)} '
                '= صافي ${FinanceDisplay.amount((debtSums[currency] ?? Decimal.zero) - (paymentSums[currency] ?? Decimal.zero))} '
                '${FinanceDisplay.currencyCode(currency)}',
              style: TextStyle(color: c.text, fontSize: 12)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: Key('pending_open_profile_${contact.id}'),
          onPressed: () => _openPendingContactDetails(contact),
          icon: const Icon(Icons.account_circle_outlined, size: 17),
          label: const Text('ملف العميل والحركة'),
        ),
        OutlinedButton.icon(
          key: Key('pending_copy_statement_${contact.id}'),
          onPressed: debtCount + paymentCount == 0 ? null :
              () => _copyPendingStatement(contact),
          icon: const Icon(Icons.copy_rounded, size: 17),
          label: const Text('نسخ كشف المبالغ لإرساله'),
        ),
        Text('يُنسخ بيان غير معتمد؛ اختر مستلمه بنفسك '
            'عند إرساله عبر واتساب أو أي وسيلة.',
          style: TextStyle(color: c.muted, fontSize: 10)),
      ]),
    );
  }

  Future<void> _copyPendingStatement(
      MerchantPendingContact contact) async {
    try {
      final now = DateTime.now();
      final report = widget.state.merchantPendingStatement(
        merchantId: widget.merchantId,
        contactId: contact.id,
        from: DateTime(2000),
        to: now,
      );
      await Clipboard.setData(ClipboardData(
        text: MerchantPendingDebtQuery.shareText(report)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم نسخ بيان المبالغ المعلقة. الصقه في '
            'واتساب بعد التحقق من مستلم الرسالة.')));
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذر نسخ البيان. تأكد من هوية التاجر.')));
    }
  }

  void _openPendingContactDetails(MerchantPendingContact contact) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => MerchantPendingContactDetailsScreen(
        state: widget.state,
        contact: contact,
        merchantId: widget.merchantId,
      ),
    ));
  }

  Widget _countBadge(AppThemeColors c, int number) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(13),
      color: c.pale,
    ),
    child: Text('$number', style: TextStyle(
      color: c.petrol, fontWeight: FontWeight.w900, fontSize: 11,
    )),
  );

  Decimal _pendingContactNet(
    MerchantPendingContact contact,
    List<MerchantPendingDebt> debts,
    List<MerchantPendingPayment> payments,
  ) {
    final currencies = _currency == null
        ? CurrencyCode.values
        : [_currency!];
    for (final currency in currencies) {
      var net = Decimal.zero;
      for (final debt in debts.where((entry) =>
          entry.contactId == contact.id && entry.merchantId == widget.merchantId &&
          entry.currency == currency)) {
        net += debt.amount;
      }
      for (final payment in payments.where((entry) =>
          entry.contactId == contact.id && entry.merchantId == widget.merchantId &&
          entry.currency == currency)) {
        net -= payment.amount;
      }
      if (net > Decimal.zero) return net;
    }
    return Decimal.zero;
  }

  bool _matchesPendingContactFilter(
    MerchantPendingContact contact,
    List<MerchantPendingDebt> debts,
    List<MerchantPendingPayment> payments,
  ) {
    final operations = [
      ...debts.where((entry) =>
          entry.contactId == contact.id && entry.merchantId == widget.merchantId &&
          (_currency == null || entry.currency == _currency)),
      ...payments.where((entry) =>
          entry.contactId == contact.id && entry.merchantId == widget.merchantId &&
          (_currency == null || entry.currency == _currency)),
    ];
    final net = _pendingContactNet(contact, debts, payments);
    return switch (_filter) {
      CustomerListFilter.all => true,
      CustomerListFilter.unpaid => net > Decimal.zero,
      CustomerListFilter.pending => operations.isNotEmpty,
      CustomerListFilter.settled => false,
      CustomerListFilter.unpaidAndPending =>
          net > Decimal.zero && operations.isNotEmpty,
    };
  }

  Widget _metrics(
    AppThemeColors c,
    List<CustomerCurrencyRow> rows, {
    required int privateContactCount,
    required int privateDebtorCount,
    required int privateOperationCount,
  }) {
    final stats = <(String, String, IconData, Color)>[
      ('إجمالي العملاء',
          '${CustomersViewModel.distinctCustomers(rows) + privateContactCount}',
          Icons.groups_rounded, c.petrol),
      ('عملاء بمديونية',
          '${CustomersViewModel.customersInDebt(rows) + privateDebtorCount}',
          Icons.account_balance_wallet_outlined, c.danger),
      ('عمليات عالقة',
          '${CustomersViewModel.pendingMovements(rows) + privateOperationCount}',
          Icons.schedule_rounded, c.pendingText),
    ];
    return Row(children: [
      for (var i = 0; i < stats.length; i++) ...[
        if (i > 0) const SizedBox(width: 7),
        Expanded(
            child: Container(
              key: Key('customers_metric_${['total', 'debtors', 'pending'][i]}'),
            padding: const EdgeInsets.symmetric(
              horizontal: 9, vertical: 11),
            constraints: const BoxConstraints(minHeight: 86),
            decoration: BoxDecoration(
              color: c.card,
              border: Border.all(color: c.cardBorder),
              borderRadius: BorderRadius.circular(13),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(stats[i].$1, style: TextStyle(
                    fontSize: 10, color: stats[i].$4,
                    fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text(stats[i].$2, style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    color: stats[i].$4,
                  ))),
                  Icon(stats[i].$3, color: stats[i].$4, size: 15),
                ]),
              ],
            ),
          ),
        ),
      ],
    ]);
  }

  // Compact, accessible menus avoid horizontal overflow of numerous chips.
  // Filtering is presentation-only: it never changes approved balances.
  Widget _currencyDropdown(AppThemeColors c) {
    return DropdownButtonFormField<CurrencyCode?>(
      key: const Key('customers_currency_dropdown'),
      initialValue: _currency,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'العملة',
        prefixIcon: Icon(Icons.payments_outlined, size: 19),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: const [
        DropdownMenuItem<CurrencyCode?>(value: null, child: Text('كل العملات')),
        DropdownMenuItem<CurrencyCode?>(value: CurrencyCode.yer, child: Text('ريال يمني')),
        DropdownMenuItem<CurrencyCode?>(value: CurrencyCode.sar, child: Text('ريال سعودي')),
        DropdownMenuItem<CurrencyCode?>(value: CurrencyCode.usd, child: Text('دولار أمريكي')),
      ],
      onChanged: (value) => setState(() => _currency = value),
    );
  }

  Widget _statusDropdown(AppThemeColors c) {
    return DropdownButtonFormField<CustomerListFilter>(
      key: const Key('customers_status_dropdown'),
      initialValue: _filter,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'الحالة',
        prefixIcon: Icon(Icons.filter_list_rounded, size: 19),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: const [
        DropdownMenuItem(value: CustomerListFilter.all, child: Text('الكل')),
        DropdownMenuItem(value: CustomerListFilter.unpaid, child: Text('غير المسدد')),
        DropdownMenuItem(value: CustomerListFilter.pending, child: Text('المعلق')),
        DropdownMenuItem(value: CustomerListFilter.settled, child: Text('مصفّى الحساب')),
        DropdownMenuItem(value: CustomerListFilter.unpaidAndPending, child: Text('دين + معلق')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _filter = value);
      },
    );
  }

  Widget _sortPicker(AppThemeColors c) {
    const labels = <CustomerSort, String>{
      CustomerSort.highestDebt: 'أعلى مديونية',
      CustomerSort.lowestDebt: 'أقل مديونية',
      CustomerSort.newest: 'الأحدث إضافة',
      CustomerSort.lastActivity: 'آخر نشاط',
    };
    return Container(
      constraints: const BoxConstraints(maxWidth: 158),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CustomerSort>(
          key: const Key('customers_sort'),
          isDense: true,
          isExpanded: true,
          value: _sort,
          style: TextStyle(
            color: c.text, fontSize: 11, fontWeight: FontWeight.w700,
          ),
          dropdownColor: c.card,
          icon: Icon(Icons.expand_more_rounded, color: c.muted, size: 16),
          items: [
            for (final sort in CustomerSort.values)
              DropdownMenuItem<CustomerSort>(
                value: sort, child: Text(labels[sort]!),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _sort = value);
          },
        ),
      ),
    );
  }

  Widget _groupTitle(AppThemeColors c, CurrencyCode currency) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: c.pale,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          FinanceDisplay.currencyName(currency),
          style: TextStyle(
            fontSize: 11, color: c.petrol, fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _customerCard(AppThemeColors c, CustomerCurrencyRow row) {
    final hasDebt = row.balance > Decimal.zero;
    final credit = row.balance < Decimal.zero;
    final color = hasDebt ? c.danger : c.petrol;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        key: Key('customer_${row.customer.id}_${row.currency.name}'),
        onTap: () => _openClientDetails(row.customer, row.currency),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: c.cardBorder),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: hasDebt
                    ? c.danger.withValues(alpha: .09) : c.pale,
                child: Text(row.customer.name.isEmpty
                    ? '؟' : row.customer.name.substring(0, 1),
                  style: TextStyle(
                    fontSize: 15, color: color,
                    fontWeight: FontWeight.w900,
                  )),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.customer.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text, fontWeight: FontWeight.w800,
                      fontSize: 13,
                    )),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.phone_outlined, size: 11, color: c.muted),
                    const SizedBox(width: 4),
                    Flexible(child: Text(
                      row.customer.phone,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: c.muted, fontSize: 10),
                    )),
                  ]),
                ],
              )),
              Icon(Icons.chevron_left_rounded, color: c.muted, size: 20),
            ]),
            const SizedBox(height: 12),
            Divider(height: 1, color: c.cardBorder),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(credit
                      ? 'رصيد دائن للعميل' : 'المديونية المتبقية',
                    style: TextStyle(color: c.muted, fontSize: 10)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      FinanceDisplay.amount(row.balance),
                      style: TextStyle(
                        color: color, fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(FinanceDisplay.currencyCode(row.currency),
                    style: TextStyle(color: c.muted, fontSize: 9)),
                ],
              )),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('مبالغ عالقة',
                    style: TextStyle(color: c.muted, fontSize: 10)),
                  const SizedBox(height: 4),
                  if (row.pendingOperations > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: c.pendingBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${FinanceDisplay.amount(row.pendingAmount)} ${FinanceDisplay.currencyCode(row.currency)}',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: c.pendingText,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Text('—', style: TextStyle(color: c.muted, fontSize: 12)),
                ],
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _pendingRelationshipCard(
      AppThemeColors c, RelationshipModel request, CustomerModel? customer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.pendingText.withValues(alpha: .22)),
      ),
      child: Row(children: [
        Icon(Icons.hourglass_top_rounded, color: c.pendingText, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer?.name ?? 'طلب ارتباط',
              style: TextStyle(
                color: c.text, fontWeight: FontWeight.w800,
                fontSize: 12)),
            const SizedBox(height: 3),
            Text('ينتظر موافقة الطرف الآخر — غير معتمد',
              style: TextStyle(color: c.pendingText, fontSize: 10)),
          ],
        )),
        Icon(Icons.lock_clock_outlined,
            color: c.pendingText, size: 18),
      ]),
    );
  }

  Widget _emptyState(AppThemeColors c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 33),
    decoration: BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: c.cardBorder),
    ),
    child: Column(children: [
      Icon(Icons.people_outline_rounded, color: c.muted, size: 34),
      const SizedBox(height: 12),
      Text('لا يوجد عملاء مطابقون للبحث أو الفلتر',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: c.text, fontWeight: FontWeight.w700, fontSize: 12,
        )),
      const SizedBox(height: 10),
      TextButton(
        key: const Key('customers_reset'),
        onPressed: () => setState(() {
          _searchController.clear();
          _currency = CurrencyCode.yer;
          _filter = CustomerListFilter.all;
          _sort = CustomerSort.highestDebt;
        }),
        child: const Text('إعادة ضبط الفلاتر'),
      ),
    ]),
  );

  void _openClientDetails(
    CustomerModel customer, CurrencyCode currency) {
    if (widget.onCustomerTap != null) {
      widget.onCustomerTap!(customer, currency);
      return;
    }
    // Standalone widget previews/tests use a route; production shell supplies
    // onCustomerTap to keep the fixed shared header and bottom navigation.
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => Scaffold(
        body: SafeArea(
          child: CustomerDetailsScreen(
            customer: customer,
            state: widget.state,
            merchantId: widget.merchantId,
            initialCurrency: currency,
            onBack: () => Navigator.of(routeContext).pop(),
          ),
        ),
      ),
    ));
  }

  void _openRequestModal() => showCustomerInvitationSheet(
    context,
    state: widget.state,
    merchantId: widget.merchantId,
  );

}
