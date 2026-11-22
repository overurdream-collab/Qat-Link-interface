import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/finance_display.dart';
import '../widgets/movement/movement_view_model.dart';

/// Financial movement page adapted from the approved HTML reference.
/// The global settings, notifications, night mode and five-item navigation
/// are hosted by MerchantAppShell, NOT duplicated inside this page.
class MerchantMovementsTab extends StatefulWidget {
  const MerchantMovementsTab({super.key, required this.state});

  final AppState state;

  @override
  State<MerchantMovementsTab> createState() => _MerchantMovementsTabState();
}

class _MerchantMovementsTabState extends State<MerchantMovementsTab> {
  final TextEditingController _searchController = TextEditingController();
  late DateTime _from;
  late DateTime _to;

  CurrencyCode? _currency = CurrencyCode.yer;
  MovementStatus? _status;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, 1);
    _to = DateTime(today.year, today.month, today.day);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart ? 'تاريخ البداية' : 'تاريخ النهاية',
    );
    if (!mounted || date == null) return;
    setState(() {
      if (isStart) {
        _from = date;
        if (_to.isBefore(date)) _to = date;
      } else {
        _to = date;
        if (_from.isAfter(date)) _from = date;
      }
    });
  }

  static String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _dayGroup(DateTime date) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _statusLabel(MovementStatus status) => switch (status) {
        MovementStatus.approved => 'معتمدة',
        MovementStatus.pending => 'عالقة',
        MovementStatus.rejected => 'مرفوضة',
      };

  Color _statusColor(MovementStatus status, AppThemeColors c) =>
      switch (status) {
        MovementStatus.approved => c.success,
        MovementStatus.pending => c.pendingText,
        MovementStatus.rejected => c.danger,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.state.movements,
        widget.state.customers,
      ]),
      builder: (context, _) {
        final customers = {
          for (final customer in widget.state.customers.value)
            customer.id: customer,
        };
        // The totals are based on period/search/currency, NOT status tabs.
        final periodRows = MovementQuery.filter(
          widget.state.movements.value,
          customers: customers,
          from: _from,
          to: _to,
          currency: _currency,
          search: _searchController.text,
        );
        final rows = _status == null
            ? periodRows
            : periodRows.where((m) => m.status == _status).toList();
        final totals = MovementQuery.totalsByCurrency(periodRows);
        final groups = MovementQuery.byDay(rows);

        return Column(
          children: [
            _fixedFilters(context, c, totals),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                children: [
                  _threeStats(c, totals),
                  const SizedBox(height: 13),
                  _statusTabs(c),
                  const SizedBox(height: 13),
                  if (rows.isEmpty)
                    AppSurface(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            color: c.muted,
                            size: 28,
                          ),
                          const SizedBox(height: 9),
                          Text(
                            'لا توجد عمليات مطابقة للبحث والفترة المختارة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final group in groups.entries) ...[
                    _groupLabel(c, group.key),
                    const SizedBox(height: 8),
                    for (final movement in group.value) ...[
                      _movementTile(c, movement, customers),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 3),
                  ],
                ],
              ),
            ),
            _reportBar(c, totals),
          ],
        );
      },
    );
  }

  Widget _fixedFilters(
    BuildContext context,
    AppThemeColors c,
    Map<CurrencyCode, MovementPeriodTotals> totals,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 10),
      decoration: BoxDecoration(
        color: c.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .04),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.pale,
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: c.petrol,
                  size: 21,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سجل الحركة', style: TextStyle(
                      color: c.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )),
                    Text('جميع تعاملاتك المالية',
                        style: TextStyle(color: c.muted, fontSize: 10)),
                  ],
                ),
              ),

            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 41,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 12, color: c.text),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'ابحث باسم العميل أو رقم العملية...',
                hintStyle: TextStyle(fontSize: 11, color: c.muted),
                prefixIcon: Icon(Icons.search_rounded, color: c.muted, size: 18),
                prefixIconConstraints: const BoxConstraints(minWidth: 37),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () => setState(_searchController.clear),
                        icon: Icon(Icons.close_rounded, color: c.muted, size: 15),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(child: _dateField(c, 'من:', _from,
                  () => _chooseDate(isStart: true))),
              const SizedBox(width: 8),
              Expanded(child: _dateField(c, 'إلى:', _to,
                  () => _chooseDate(isStart: false))),
            ],
          ),
          const SizedBox(height: 8),
          _currencyPicker(c),
          const SizedBox(height: 9),
          _grossBanner(c, totals),
        ],
      ),
    );
  }

  Widget _dateField(
    AppThemeColors c,
    String label,
    DateTime date,
    VoidCallback action,
  ) {
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: action,
        child: Container(
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            border: Border.all(color: c.cardBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(label, style: TextStyle(color: c.muted, fontSize: 10)),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(_date(date), style: TextStyle(
                    color: c.text, fontSize: 11, fontWeight: FontWeight.w700,
                  )),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.calendar_month_outlined, color: c.petrol, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _currencyPicker(AppThemeColors c) {
    final options = <(CurrencyCode?, String)>[
      (CurrencyCode.yer, 'YER'),
      (CurrencyCode.sar, 'SAR'),
      (CurrencyCode.usd, 'USD'),
      (null, 'كل العملات'),
    ];
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.$1 == _currency;
          return Material(
            color: selected ? c.petrol : c.card,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => setState(() => _currency = option.$1),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? c.petrol : c.cardBorder,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  option.$2,
                  style: TextStyle(
                    color: selected ? (Theme.of(context).brightness ==
                            Brightness.dark ? AppColors.darkBackground : Colors.white)
                        : c.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _grossBanner(
    AppThemeColors c,
    Map<CurrencyCode, MovementPeriodTotals> totals,
  ) {
    final isAll = _currency == null;
    final single = _currency == null ? null : totals[_currency!];
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 91),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: AppGradients.assistant,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: c.petrol.withValues(alpha: .16),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.trending_up_rounded, color: Colors.white, size: 23,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي الحركة للفترة المحددة',
                  style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 11,
                  )),
                SizedBox(height: 4),
                Text('مبالغ العمليات غير المرفوضة، بما فيها المعلقة',
                  maxLines: 2,
                  style: TextStyle(color: Colors.white70, fontSize: 9)),
              ],
            ),
          ),
          const SizedBox(width: 5),
          if (isAll)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final currency in CurrencyCode.values)
                  Text(
                    '${FinanceDisplay.amount(totals[currency]!.grossNonRejected)} ${FinanceDisplay.currencyCode(currency)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    FinanceDisplay.amount(single!.grossNonRejected),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 23,
                    ),
                  ),
                ),
                Text(FinanceDisplay.currencySymbol(_currency!),
                  style: const TextStyle(
                    color: Colors.white70, fontSize: 11,
                  )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _threeStats(
    AppThemeColors c,
    Map<CurrencyCode, MovementPeriodTotals> totals,
  ) {
    final cards = <(String, IconData, Color, String Function(MovementPeriodTotals))>[
      ('ديون معتمدة', Icons.arrow_upward_rounded, c.cyan,
          (m) => FinanceDisplay.amount(m.approvedDebts)),
      ('عمليات عالقة', Icons.schedule_rounded, c.pendingText,
          (m) => FinanceDisplay.amount(m.pending)),
      ('تحصيلات معتمدة', Icons.check_rounded, c.success,
          (m) => FinanceDisplay.amount(m.approvedPayments)),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: Container(
            constraints: const BoxConstraints(minHeight: 66),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: c.cardBorder),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: cards[i].$3,
                  radius: 10,
                  child: Icon(cards[i].$2, size: 11, color: Colors.white),
                ),
                const SizedBox(height: 5),
                if (_currency == null)
                  for (final currency in CurrencyCode.values)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${cards[i].$4(totals[currency]!)} ${FinanceDisplay.currencyCode(currency)}',
                        style: TextStyle(
                          color: c.text, fontSize: 9, fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      cards[i].$4(totals[_currency!]!),
                      style: TextStyle(
                        color: c.text, fontWeight: FontWeight.w800, fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(cards[i].$1,
                    style: TextStyle(color: c.muted, fontSize: 9)),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _statusTabs(AppThemeColors c) {
    final options = <(MovementStatus?, String, IconData)>[
      (null, 'الكل', Icons.grid_view_rounded),
      (MovementStatus.approved, 'المعتمدة', Icons.check_circle_outline_rounded),
      (MovementStatus.pending, 'العالقة', Icons.schedule_outlined),
      (MovementStatus.rejected, 'المرفوضة', Icons.cancel_outlined),
    ];
    return Row(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(width: 5),
          Expanded(child: Material(
            color: _status == options[index].$1 ? c.petrol : c.card,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => setState(() => _status = options[index].$1),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _status == options[index].$1
                      ? c.petrol : c.cardBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(options[index].$3, size: 12,
                        color: _status == options[index].$1
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkBackground : Colors.white)
                            : c.petrol),
                      const SizedBox(width: 3),
                      Text(
                        options[index].$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _status == options[index].$1
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkBackground : Colors.white)
                              : c.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )),
        ],
      ],
    );
  }

  Widget _groupLabel(AppThemeColors c, DateTime date) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: c.pale, borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        Text(_dayGroup(date), style: TextStyle(
          color: c.text, fontSize: 11, fontWeight: FontWeight.w700,
        )),
        const Spacer(),
        Icon(Icons.calendar_today_outlined, size: 13, color: c.petrol),
      ],
    ),
  );

  Widget _movementTile(
    AppThemeColors c,
    MovementModel m,
    Map<String, CustomerModel> customers,
  ) {
    final name = customers[m.customerId]?.name ?? 'عميل';
    final isDebt = m.type == MovementType.debt;
    final statusColor = _statusColor(m.status, c);
    final amountColor = m.status == MovementStatus.rejected
        ? c.muted
        : m.status == MovementStatus.pending
            ? c.pendingText
            : isDebt ? c.success : c.danger;
    final sign = isDebt ? '+' : '−';
    final hour = TimeOfDay.fromDateTime(m.createdAt).format(context);
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showMovementDetails(m, name, c),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.cardBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.pale,
                child: Icon(Icons.person_rounded, size: 18, color: c.petrol),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text, fontSize: 12,
                        fontWeight: FontWeight.w800,
                      )),
                    const SizedBox(height: 4),
                    Text(
                      '${isDebt ? 'إضافة دين' : 'تسجيل تسديد'} • $hour',
                      style: TextStyle(color: c.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${FinanceDisplay.amount(m.amount)} ${FinanceDisplay.currencySymbol(m.currency)}',
                    style: TextStyle(
                      color: amountColor, fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: m.status == MovementStatus.pending
                          ? c.pendingBackground
                          : statusColor.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          m.status == MovementStatus.approved
                              ? Icons.check_circle_rounded
                              : m.status == MovementStatus.pending
                                  ? Icons.schedule_rounded
                                  : Icons.cancel_rounded,
                          size: 10, color: statusColor,
                        ),
                        const SizedBox(width: 3),
                        Text(_statusLabel(m.status), style: TextStyle(
                          color: statusColor, fontSize: 9,
                          fontWeight: FontWeight.w700,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMovementDetails(
    MovementModel m,
    String customerName,
    AppThemeColors c,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('تفاصيل الحركة', style: TextStyle(
                color: c.petrol, fontSize: 17, fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 13),
              _detailsLine(c, 'العميل', customerName),
              _detailsLine(c, 'رقم العملية', m.id),
              _detailsLine(c, 'النوع',
                  m.type == MovementType.debt ? 'دين' : 'تسديد'),
              _detailsLine(c, 'الحالة', _statusLabel(m.status)),
              _detailsLine(c, 'المبلغ',
                  '${FinanceDisplay.amount(m.amount)} ${FinanceDisplay.currencyCode(m.currency)}'),
              _detailsLine(c, 'التاريخ', _date(m.createdAt)),
              if (m.description != null)
                _detailsLine(c, 'البيان', m.description!),
              if (m.status == MovementStatus.pending)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'هذه الحركة معلقة ولا تؤثر في الرصيد المعتمد.',
                    style: TextStyle(color: c.pendingText, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailsLine(AppThemeColors c, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(
            color: c.muted, fontSize: 11,
          )),
        ),
        Expanded(child: SelectableText(value, style: TextStyle(
          color: c.text, fontWeight: FontWeight.w600, fontSize: 12,
        ))),
      ],
    ),
  );

  Widget _reportBar(
    AppThemeColors c,
    Map<CurrencyCode, MovementPeriodTotals> totals,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.cardBorder)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.pale,
          border: Border.all(color: c.cardBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.petrol,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.picture_as_pdf_outlined,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkBackground : Colors.white,
                size: 17),
            ),
            const SizedBox(width: 9),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كشف الحركة', style: TextStyle(
                  color: c.petrol, fontSize: 12, fontWeight: FontWeight.w800,
                )),
                const SizedBox(height: 2),
                Text('عرض ملخص الفترة المحددة',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 9)),
              ],
            )),
            FilledButton(
              onPressed: () => _showReport(c, totals),
              style: FilledButton.styleFrom(
                minimumSize: const Size(92, 32),
                padding: const EdgeInsets.symmetric(horizontal: 9),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 10),
              ),
              child: const Text('إصدار التقرير'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReport(
    AppThemeColors c,
    Map<CurrencyCode, MovementPeriodTotals> totals,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('كشف الحركة', style: TextStyle(
                color: c.petrol, fontSize: 17, fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 4),
              Text('الفترة: ${_date(_from)} — ${_date(_to)}',
                style: TextStyle(color: c.muted, fontSize: 11)),
              const SizedBox(height: 10),
              for (final currency in CurrencyCode.values)
                if (_currency == null || _currency == currency) ...[
                  Text(FinanceDisplay.currencyName(currency),
                    style: TextStyle(color: c.petrol, fontWeight: FontWeight.w800)),
                  _detailsLine(c, 'إجمالي الحركة',
                    FinanceDisplay.amount(totals[currency]!.grossNonRejected)),
                  _detailsLine(c, 'الديون المعتمدة',
                    FinanceDisplay.amount(totals[currency]!.approvedDebts)),
                  _detailsLine(c, 'المعلق',
                    FinanceDisplay.amount(totals[currency]!.pending)),
                  _detailsLine(c, 'التسديد المعتمد',
                    FinanceDisplay.amount(totals[currency]!.approvedPayments)),
                  const SizedBox(height: 8),
                ],
              Text('التصدير إلى PDF غير متصل بعد بخدمة التقارير.',
                style: TextStyle(color: c.muted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
