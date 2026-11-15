import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/customers/customers_view_model.dart';
import '../widgets/finance_display.dart';
import '../widgets/movement/movement_view_model.dart';

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
  });

  final AppState state;

  /// Must be resolved from an authenticated server-side session in production.
  final String? merchantId;

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

  void _notice(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.state.customers,
        widget.state.relationships,
        widget.state.movements,
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
        final pending = CustomersViewModel.pendingRelationships(
          rels, merchantId: widget.merchantId,
        );
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
                    Text('مقوتي لنك • العلاقات المعتمدة',
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
            _metrics(c, metricRows),
            const SizedBox(height: 18),
            Text('تصفية حسب العملة:', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: c.muted,
            )),
            const SizedBox(height: 7),
            _currencyChips(c),
            const SizedBox(height: 13),
            Text('الحالة:', style: TextStyle(
              color: c.muted, fontSize: 12, fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 6),
            _statusFilters(c),
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
                _countBadge(c, CustomersViewModel.distinctCustomers(visible)),
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
          ],
        );
      },
    );
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

  Widget _metrics(AppThemeColors c, List<CustomerCurrencyRow> rows) {
    final stats = <(String, String, IconData, Color)>[
      ('إجمالي العملاء',
          '${CustomersViewModel.distinctCustomers(rows)}',
          Icons.groups_rounded, c.petrol),
      ('عملاء بمديونية',
          '${CustomersViewModel.customersInDebt(rows)}',
          Icons.account_balance_wallet_outlined, c.danger),
      ('عمليات عالقة',
          '${CustomersViewModel.pendingMovements(rows)}',
          Icons.schedule_rounded, c.pendingText),
    ];
    return Row(children: [
      for (var i = 0; i < stats.length; i++) ...[
        if (i > 0) const SizedBox(width: 7),
        Expanded(
          child: Container(
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

  Widget _currencyChips(AppThemeColors c) => SizedBox(
    height: 37,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _currencyChip(c, null, 'كل العملات'),
        const SizedBox(width: 7),
        _currencyChip(c, CurrencyCode.yer, 'ريال يمني YER'),
        const SizedBox(width: 7),
        _currencyChip(c, CurrencyCode.sar, 'ريال سعودي SAR'),
        const SizedBox(width: 7),
        _currencyChip(c, CurrencyCode.usd, 'دولار USD'),
      ],
    ),
  );

  Widget _currencyChip(
      AppThemeColors c, CurrencyCode? value, String label) {
    final selected = _currency == value;
    return ChoiceChip(
      key: Key('customers_currency_${value?.name ?? 'ALL'}'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _currency = value),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 11,
        color: selected ? c.petrol : c.text,
      ),
      selectedColor: c.pale,
      backgroundColor: c.card,
      side: BorderSide(
        color: selected ? c.petrol : c.cardBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      padding: const EdgeInsets.symmetric(horizontal: 7),
    );
  }

  Widget _statusFilters(AppThemeColors c) {
    const labels = <CustomerListFilter, String>{
      CustomerListFilter.all: 'الكل',
      CustomerListFilter.unpaid: 'غير المسدد',
      CustomerListFilter.pending: 'المعلق',
      CustomerListFilter.settled: 'مصفّى الحساب',
      CustomerListFilter.unpaidAndPending: 'دين + معلق',
    };
    return SizedBox(
      height: 37,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final value = labels.keys.elementAt(index);
          final selected = _filter == value;
          return ChoiceChip(
            key: Key('customers_filter_${value.name}'),
            selected: selected,
            onSelected: (_) => setState(() => _filter = value),
            showCheckmark: false,
            label: Text(labels[value]!),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? c.petrol : c.text,
            ),
            selectedColor: c.pale,
            backgroundColor: c.card,
            side: BorderSide(
              color: selected ? c.petrol : c.cardBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          );
        },
      ),
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
        onTap: () => _openClientDetails(row.customer),
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

  void _openClientDetails(CustomerModel customer) {
    final c = context.colors;
    final balances = CustomersViewModel.rows(
      customers: [customer],
      relationships: widget.state.relationships.value,
      movements: widget.state.movements.value,
      currency: null,
      merchantId: widget.merchantId,
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(customer.name, style: TextStyle(
                color: c.petrol, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(customer.phone, textDirection: TextDirection.ltr,
                style: TextStyle(color: c.muted)),
              const SizedBox(height: 14),
              for (final row in balances) ...[
                Text(FinanceDisplay.currencyName(row.currency),
                  style: TextStyle(
                    color: c.petrol, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('الرصيد المعتمد: ${FinanceDisplay.amount(row.balance)}',
                  style: TextStyle(color: c.text)),
                Text('المعلق: ${FinanceDisplay.amount(row.pendingAmount)}',
                  style: TextStyle(color: c.pendingText)),
                const SizedBox(height: 10),
              ],
              Text(
                'هذا ملخص قرائي؛ شاشة تفاصيل العميل الكاملة قيد التطوير.',
                style: TextStyle(color: c.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRequestModal() {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          19, 10, 19, MediaQuery.viewInsetsOf(sheet).bottom + 19,
        ),
        child: SafeArea(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      color: c.petrol, size: 22),
                  const SizedBox(width: 8),
                  Text('طلب إضافة عميل', style: TextStyle(
                    color: c.text, fontSize: 16,
                    fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 9),
                Text(
                  'يتطلب انضمام العميل موافقته. '
                  'لن تُنشأ علاقة مالية قبل اعتماد الطرفين.',
                  style: TextStyle(color: c.muted, fontSize: 11)),
                const SizedBox(height: 15),
                TextFormField(
                  key: const Key('new_customer_name'),
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v ?? '').trim().length < 3
                      ? 'أدخل اسم العميل'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('new_customer_phone'),
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم هاتف العميل',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                  validator: (v) {
                    final input = (v ?? '').replaceAll(
                      RegExp(r'[\s\-\(\)]'), '');
                    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(input)) {
                      return 'أدخل رقم جوال صحيحاً';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: c.pale, borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(11),
                  child: Text(
                    'لا تُدخل أي مديونية أولية هنا؛ '
                    'الديون والتسديدات عمليات مستقلة تتطلب الموافقة.',
                    style: TextStyle(
                      color: c.petrol, fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('request_customer_link'),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final normalizedPhone = MovementQuery.normalizeSearch(
                      phone.text);
                    final customer = widget.state.customers.value.where(
                      (existing) =>
                        MovementQuery.normalizeSearch(existing.phone) ==
                        normalizedPhone,
                    );
                    if (customer.isEmpty) {
                      _notice('الرقم غير مرتبط بحساب عميل محمّل. '
                          'يتطلب إرسال الدعوة التحقق من الحساب عبر الخادم.');
                    } else if (widget.state.relationships.value.any(
                        (r) => r.customerId == customer.first.id &&
                            r.status != RelationshipStatus.cancelled)) {
                      _notice('يوجد ارتباط أو طلب ارتباط سابق لهذا العميل.');
                    } else {
                      // A trusted authenticated merchant identity and the
                      // backend request API are not available in this build.
                      // Never fake a successful invitation locally.
                      _notice('المدخلات جاهزة. إرسال الطلب يحتاج جلسة '
                          'تاجر موثّقة وخدمة علاقات آمنة.');
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
                  child: const Text('إرسال طلب ارتباط',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 7),
                OutlinedButton(
                  onPressed: () => Navigator.of(sheet).pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      name.dispose();
      phone.dispose();
    });
  }
}
