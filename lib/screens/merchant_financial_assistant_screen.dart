import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/premium_tokens.dart';
import '../widgets/finance_display.dart';

enum _Period { daily, weekly, firstHalf, secondHalf, monthly }

class _Range {
  const _Range(this.start, this.end, this.previousStart, this.previousEnd);
  final DateTime start;
  final DateTime end;
  final DateTime previousStart;
  final DateTime previousEnd;

  bool includes(DateTime date) =>
      !date.isBefore(start) && date.isBefore(end);
  bool includesPrevious(DateTime date) =>
      !date.isBefore(previousStart) && date.isBefore(previousEnd);
}

class MerchantFinancialAssistantScreen extends StatefulWidget {
  const MerchantFinancialAssistantScreen({
    super.key,
    required this.state,
  });

  final AppState state;

  @override
  State<MerchantFinancialAssistantScreen> createState() =>
      _MerchantFinancialAssistantScreenState();
}

class _MerchantFinancialAssistantScreenState
    extends State<MerchantFinancialAssistantScreen> {
  _Period _period = _Period.monthly;
  CurrencyCode _currency = CurrencyCode.yer;
  int _half = 1;
  int _customerTab = 0;

  static final Decimal _zero = Decimal.zero;
  static final Decimal _hundred = Decimal.fromInt(100);

  _Range _range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final month = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);
    switch (_period) {
      case _Period.daily:
        return _Range(today, today.add(const Duration(days: 1)),
            today.subtract(const Duration(days: 1)), today);
      case _Period.weekly:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return _Range(start, start.add(const Duration(days: 7)),
            start.subtract(const Duration(days: 7)), start);
      case _Period.firstHalf:
        return _Range(DateTime(now.year, now.month, 1),
            DateTime(now.year, now.month, 16),
            DateTime(previousMonth.year, previousMonth.month, 1),
            DateTime(previousMonth.year, previousMonth.month, 16));
      case _Period.secondHalf:
        return _Range(DateTime(now.year, now.month, 16),
            DateTime(now.year, now.month + 1),
            DateTime(previousMonth.year, previousMonth.month, 16), month);
      case _Period.monthly:
        return _Range(month, DateTime(now.year, now.month + 1),
            previousMonth, month);
    }
  }

  String get _periodLabel => switch (_period) {
        _Period.daily => 'اليوم',
        _Period.weekly => 'هذا الأسبوع',
        _Period.firstHalf => 'النصف الأول من الشهر',
        _Period.secondHalf => 'النصف الثاني من الشهر',
        _Period.monthly => 'هذا الشهر',
      };

  List<MovementModel> _rows() => widget.state.movements.value
      .where((row) => row.currency == _currency)
      .toList(growable: false);

  List<MovementModel> _between(
    List<MovementModel> rows,
    bool Function(DateTime) test,
  ) => rows.where((row) => test(row.createdAt)).toList(growable: false);

  Decimal _sum(
    Iterable<MovementModel> rows,
    MovementType type,
    MovementStatus status,
  ) {
    var total = _zero;
    for (final row in rows) {
      if (row.type == type && row.status == status) total += row.amount;
    }
    return total;
  }

  int _percent(Decimal part, Decimal whole) {
    if (whole <= _zero) return 0;
    final value = (part * _hundred / whole).toDouble().round();
    return value.clamp(0, 100);
  }

  String _amount(Decimal value) =>
      '${FinanceDisplay.amount(value)} ${FinanceDisplay.currencySymbol(_currency)}';

  Decimal _sumOutsideDebts(bool Function(DateTime) inPeriod) {
    var total = _zero;
    for (final row in widget.state.merchantPendingDebts.value) {
      if (row.currency == _currency && inPeriod(row.createdAt)) total += row.amount;
    }
    return total;
  }

  Decimal _sumOutsidePayments(bool Function(DateTime) inPeriod) {
    var total = _zero;
    for (final row in widget.state.merchantPendingPayments.value) {
      if (row.currency == _currency && inPeriod(row.createdAt)) total += row.amount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('المساعد المالي الذكي',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        leading: IconButton(
          key: const Key('assistant_back'),
          tooltip: 'العودة',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          widget.state.movements,
          widget.state.customers,
          widget.state.merchantContacts,
          widget.state.merchantPendingDebts,
          widget.state.merchantPendingPayments,
        ]),
        builder: (context, _) {
          final rows = _rows();
          final range = _range(DateTime.now());
          final current = _between(rows, range.includes);
          final previous = _between(rows, range.includesPrevious);
          final debts = _sum(current, MovementType.debt, MovementStatus.approved);
          final payments = _sum(current, MovementType.payment, MovementStatus.approved);
          final pendingDebts = _sum(current, MovementType.debt, MovementStatus.pending);
          final pendingPayments = _sum(current, MovementType.payment, MovementStatus.pending);
          final outsideDebts = _sumOutsideDebts(range.includes);
          final outsidePayments = _sumOutsidePayments(range.includes);
          final registered = debts + pendingDebts + outsideDebts;
          final allPendingDebts = pendingDebts + outsideDebts;
          final allPendingPayments = pendingPayments + outsidePayments;
          final operationalNet = registered - payments - allPendingPayments;
          final paid = payments < debts ? payments : debts;
          final unpaid = debts > payments ? debts - payments : _zero;
          final credit = payments > debts ? payments - debts : _zero;
          final approvalRate = _percent(debts, registered);
          final collectionRate = _percent(payments, debts);
          final hasData = current.any((row) => row.status != MovementStatus.rejected) ||
              outsideDebts > _zero || outsidePayments > _zero;
          final health = ((approvalRate * 4 + collectionRate * 6) / 10).round();
          final oldPending = current.where((row) =>
              row.type == MovementType.debt &&
              row.status == MovementStatus.pending &&
              DateTime.now().difference(row.createdAt).inDays >= 7).length +
              widget.state.merchantPendingDebts.value.where((row) =>
                row.currency == _currency &&
                range.includes(row.createdAt) &&
                DateTime.now().difference(row.createdAt).inDays >= 7).length;
          final previousDebts = _sum(previous, MovementType.debt, MovementStatus.approved);
          final growth = previousDebts <= _zero
              ? null
              : ((debts - previousDebts) * _hundred / previousDebts)
                  .toDouble().round();
          final customers = _customerInsights(rows, range);

          return ListView(
            key: const Key('merchant_financial_assistant_screen'),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              _sourceNotice(c),
              const SizedBox(height: 11),
              _periodSelector(c),
              if (_period == _Period.firstHalf || _period == _Period.secondHalf) ...[
                const SizedBox(height: 7),
                _halfSelector(c),
              ],
              const SizedBox(height: 12),
              _card(c, 'النظرة الشاملة ومؤشر المتابعة',
                Icons.health_and_safety_outlined,
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _currencySelector(c),
                  const SizedBox(height: 11),
                  Row(children: [
                    SizedBox(width: 70, height: 70,
                      child: Stack(alignment: Alignment.center, children: [
                        CircularProgressIndicator(
                          value: hasData ? health / 100 : 0,
                          strokeWidth: 6,
                          color: c.mint,
                          backgroundColor: c.cardBorder),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(hasData ? '$health%' : '—',
                            style: TextStyle(color: c.text,
                              fontWeight: FontWeight.w900, fontSize: 15)),
                          Text(_healthLabel(health, hasData),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.success, fontSize: 8)),
                        ]),
                      ])),
                    const SizedBox(width: 11),
                    Expanded(child: Text(
                      hasData
                        ? 'مؤشر حسابي تقريبي: اعتماد الديون $approvalRate%، والتحصيل من الديون المعتمدة $collectionRate%.'
                        : 'لا توجد حركات بهذه العملة خلال $_periodLabel.',
                      style: TextStyle(color: c.muted, fontSize: 10, height: 1.5))),
                    if (growth != null) _growth(c, growth),
                  ]),
                  const SizedBox(height: 10),
                  _metricGrid(c, [
                    _Metric('الديون المسجلة', registered, Icons.receipt_long_outlined,
                      c.text, 'تشمل العملاء خارج التطبيق، دون المرفوضة'),
                    _Metric('الديون المعتمدة', debts, Icons.verified_outlined,
                      c.petrol, 'تدخل في الرصيد المعتمد'),
                    _Metric('المسدد من المعتمد', paid, Icons.payments_outlined,
                      c.success, 'حتى قيمة الديون المعتمدة'),
                    _Metric('المتبقي المعتمد', unpaid,
                      Icons.account_balance_wallet_outlined, c.pendingText,
                      credit > _zero ? 'رصيد دائن: ${_amount(credit)}' : 'بعد خصم الدفعات'),
                    _Metric('معلقة — بانتظار موافقة العميل', pendingDebts,
                      Icons.hourglass_top_rounded, c.danger,
                      'لا تدخل في الرصيد المعتمد'),
                    _Metric('معلقة — بانتظار انضمام العميل', outsideDebts,
                      Icons.person_add_alt_1_outlined, c.pendingText,
                      'عملاء خارج التطبيق'),
                    _Metric('دفعات معلقة', allPendingPayments,
                      Icons.pending_actions_outlined, c.danger,
                      'لا تخفض الرصيد قبل اعتمادها'),
                    _Metric('دفعات مسجلة خارج التطبيق', outsidePayments,
                      Icons.payments_outlined, c.pendingText,
                      'تخفض الصافي التشغيلي فقط'),
                    _Metric('الدفعات المعتمدة', payments,
                      Icons.savings_outlined, c.cyan,
                      'تشمل الرصيد الدائن إن وجد'),
                    _Metric('صافي الحركة التشغيلية', operationalNet,
                      Icons.account_balance_wallet_outlined, c.text,
                      'للفترة والعملة المحددتين فقط'),
                  ]),
                ])),
              const SizedBox(height: 12),
              _card(c, 'تحليل الحركة والتحصيل', Icons.show_chart_rounded,
                _movementSummary(c, rows, range, debts, payments, previousDebts)),
              const SizedBox(height: 12),
              _card(c, 'تحليل العملاء', Icons.groups_2_outlined,
                _customerSection(c, customers)),
              const SizedBox(height: 12),
              _card(c, 'تنبيهات ومؤشرات', Icons.notifications_active_outlined,
                Column(children: [
                  _alert(c, 'ديون بانتظار اعتماد العملاء',
                    _amount(pendingDebts), c.danger),
                  _alert(c, 'ديون مسجلة لعملاء خارج التطبيق',
                    _amount(outsideDebts), c.pendingText),
                  _alert(c, 'دفعات بانتظار الاعتماد',
                    _amount(allPendingPayments), c.pendingText),
                  if (oldPending > 0)
                    _alert(c, 'ديون معلقة منذ 7 أيام أو أكثر',
                      '$oldPending عملية تحتاج مراجعة', c.danger),
                ])),
              const SizedBox(height: 12),
              _card(c, 'اقتراحات المتابعة', Icons.lightbulb_outline_rounded,
                _recommendations(c, unpaid, allPendingDebts, oldPending)),
            ],
          );
        },
      ),
    );
  }

  String _healthLabel(int score, bool hasData) {
    if (!hasData) return 'لا بيانات';
    if (score >= 85) return 'جيد جداً';
    if (score >= 70) return 'جيد';
    if (score >= 50) return 'متابعة';
    return 'مراجعة';
  }

  Widget _sourceNotice(AppThemeColors c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: c.pendingBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.cardBorder)),
    child: Row(children: [
      Icon(Icons.info_outline, size: 17, color: c.pendingText),
      const SizedBox(width: 7),
      Expanded(child: Text(
        'قراءة أولية من الحركات المحمّلة على الجهاز؛ ليست تحليلاً من الخادم أو ذكاءً اصطناعياً.',
        style: TextStyle(color: c.text, fontSize: 9, height: 1.4))),
    ]));

  Widget _periodSelector(AppThemeColors c) {
    const options = [
      (_Period.daily, 'يومي'),
      (_Period.weekly, 'أسبوعي'),
      (_Period.firstHalf, 'نصف شهري'),
      (_Period.monthly, 'شهري'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.pale,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder)),
      child: Row(children: [
        for (final option in options)
          Expanded(child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() {
              _period = option.$1;
              if (_period == _Period.firstHalf) _half = 1;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              decoration: BoxDecoration(
                color: _period == option.$1 ||
                    (_period == _Period.secondHalf && option.$1 == _Period.firstHalf)
                  ? c.card : Colors.transparent,
                borderRadius: BorderRadius.circular(9)),
              child: Text(option.$2, textAlign: TextAlign.center,
                style: TextStyle(color: c.petrol, fontSize: 9,
                  fontWeight: FontWeight.w800)),
            ),
          )),
      ]));
  }

  Widget _halfSelector(AppThemeColors c) => Row(children: [
    Expanded(child: _halfButton(c, 1, 'الفترة الأولى (1–15)')),
    const SizedBox(width: 7),
    Expanded(child: _halfButton(c, 2, 'الفترة الثانية (16–نهاية الشهر)')),
  ]);

  Widget _halfButton(AppThemeColors c, int half, String label) =>
      OutlinedButton(
        onPressed: () => setState(() {
          _half = half;
          _period = half == 1 ? _Period.firstHalf : _Period.secondHalf;
        }),
        style: OutlinedButton.styleFrom(
          backgroundColor: _half == half ? c.petrol : c.card,
          foregroundColor: _half == half ? c.card : c.petrol,
          side: BorderSide(color: c.cardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6)),
        child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9)));

  Widget _currencySelector(AppThemeColors c) => Wrap(spacing: 6, children: [
    for (final currency in CurrencyCode.values)
      ChoiceChip(
        key: Key('assistant_currency_${currency.name}'),
        label: Text(FinanceDisplay.currencySymbol(currency)),
        selected: currency == _currency,
        onSelected: (_) => setState(() => _currency = currency),
        selectedColor: c.pale,
        backgroundColor: c.card,
        side: BorderSide(color: c.cardBorder),
        labelStyle: TextStyle(color: c.petrol,
          fontWeight: FontWeight.w800, fontSize: 10)),
  ]);

  Widget _metricGrid(AppThemeColors c, List<_Metric> metrics) =>
      LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 7) / 2;
        return Wrap(spacing: 7, runSpacing: 7, children: [
          for (final metric in metrics)
            SizedBox(width: width, child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: c.background,
                border: Border.all(color: c.cardBorder),
                borderRadius: BorderRadius.circular(11)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(metric.icon, color: metric.color, size: 14),
                    const SizedBox(width: 4),
                    Expanded(child: Text(metric.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 8,
                        fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 5),
                  Text(_amount(metric.value), maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.text, fontSize: 11,
                      fontWeight: FontWeight.w900)),
                  Text(metric.note, maxLines: 2,
                    style: TextStyle(color: c.muted, fontSize: 8)),
                ]))),
        ]);
      });

  Widget _movementSummary(
    AppThemeColors c,
    List<MovementModel> rows,
    _Range range,
    Decimal debts,
    Decimal payments,
    Decimal previousDebts,
  ) {
    const bucketCount = 6;
    final span = range.end.difference(range.start).inMilliseconds;
    final starts = List.generate(bucketCount, (i) =>
      range.start.add(Duration(milliseconds: span * i ~/ bucketCount)));
    final debtBuckets = List<Decimal>.filled(bucketCount, _zero);
    final paymentBuckets = List<Decimal>.filled(bucketCount, _zero);

    for (final row in rows) {
      if (!range.includes(row.createdAt) ||
          row.status != MovementStatus.approved) continue;
      var index = starts.lastIndexWhere((start) => !row.createdAt.isBefore(start));
      if (index < 0) continue;
      if (index >= bucketCount) index = bucketCount - 1;
      if (row.type == MovementType.debt) {
        debtBuckets[index] += row.amount;
      } else {
        paymentBuckets[index] += row.amount;
      }
    }

    final maxValue = [...debtBuckets, ...paymentBuckets].fold<Decimal>(
      _zero, (largest, value) => value > largest ? value : largest);
    final delta = previousDebts <= _zero
        ? null
        : ((debts - previousDebts) * _hundred / previousDebts)
            .toDouble().round();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ديون معتمدة ودفعات معتمدة في $_periodLabel',
        style: TextStyle(color: c.muted, fontSize: 9)),
      const SizedBox(height: 10),
      Row(children: [
        _legend(c.petrol, 'الديون'),
        const SizedBox(width: 12),
        _legend(c.cyan, 'الدفعات'),
      ]),
      const SizedBox(height: 8),
      SizedBox(height: 112, child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < bucketCount; i++)
            Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chartBar(c, debtBuckets[i], maxValue, c.petrol),
                    const SizedBox(width: 3),
                    _chartBar(c, paymentBuckets[i], maxValue, c.cyan),
                  ],
                )),
                const SizedBox(height: 4),
                Text(_bucketLabel(starts[i]),
                  style: TextStyle(color: c.muted, fontSize: 7)),
              ],
            )),
        ],
      )),
      const SizedBox(height: 7),
      Text(delta == null ? 'لا تتوفر فترة سابقة للمقارنة.'
        : 'تغير الديون المعتمدة عن الفترة السابقة: ${delta >= 0 ? '+' : ''}$delta%',
        style: TextStyle(color: c.muted, fontSize: 9)),
      const SizedBox(height: 3),
      Text('الرسم يعرض الحركات المعتمدة فقط؛ ولا يجمع العملات.',
        style: TextStyle(color: c.muted, fontSize: 8)),
    ]);
  }

  Widget _chartBar(
    AppThemeColors c,
    Decimal value,
    Decimal maxValue,
    Color color,
  ) {
    final fraction = maxValue <= _zero
        ? 0.0
        : (value / maxValue).toDouble().clamp(0.0, 1.0);
    return Expanded(child: FractionallySizedBox(
      heightFactor: fraction == 0 ? 0.025 : fraction,
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(minHeight: 2),
        decoration: BoxDecoration(
          color: fraction == 0 ? c.cardBorder : color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
    ));
  }

  String _bucketLabel(DateTime date) => _period == _Period.daily
      ? '${date.hour.toString().padLeft(2, '0')}:00'
      : '${date.day}/${date.month}';

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: context.colors.muted, fontSize: 8)),
    ],
  );

  List<_Insight> _customerInsights(List<MovementModel> rows, _Range range) {
    final names = {
      for (final customer in widget.state.customers.value)
        customer.id: customer.name,
    };
    final ids = rows
        .where((row) =>
            row.status == MovementStatus.approved &&
            row.type == MovementType.debt &&
            (range.includes(row.createdAt) ||
                range.includesPrevious(row.createdAt)))
        .map((row) => row.customerId)
        .toSet();
    final results = <_Insight>[];

    for (final id in ids) {
      Decimal total(bool Function(DateTime) inPeriod, MovementType type) {
        var amount = _zero;
        for (final row in rows) {
          if (row.customerId == id &&
              row.type == type &&
              row.status == MovementStatus.approved &&
              inPeriod(row.createdAt)) {
            amount += row.amount;
          }
        }
        return amount;
      }

      final debts = total(range.includes, MovementType.debt);
      final previousDebts = total(range.includesPrevious, MovementType.debt);
      final payments = total(range.includes, MovementType.payment);
      final collection = _percent(payments, debts);
      final change = previousDebts <= _zero
          ? (debts <= _zero ? 0 : 100)
          : ((debts - previousDebts) * _hundred / previousDebts)
              .toDouble()
              .round();
      results.add(_Insight(names[id] ?? 'عميل', debts, collection, change));
    }

    if (_customerTab == 0) {
      results.sort((a, b) => b.debt.compareTo(a.debt));
    } else if (_customerTab == 1) {
      results.removeWhere((item) => item.debt <= _zero);
      results.sort((a, b) => b.collection.compareTo(a.collection));
    } else {
      results.sort((a, b) => b.change.abs().compareTo(a.change.abs()));
    }
    return results.take(3).toList(growable: false);
  }

  Widget _customerSection(AppThemeColors c, List<_Insight> insights) =>
      Column(children: [
        Row(children: [
          _tab(c, 0, 'الأكثر شراءً'),
          _tab(c, 1, 'الأفضل تحصيلاً'),
          _tab(c, 2, 'تغير المشتريات'),
        ]),
        const SizedBox(height: 8),
        if (insights.isEmpty)
          Text('لا توجد حركات معتمدة لعرض ترتيب العملاء.',
            style: TextStyle(color: c.muted, fontSize: 9))
        else for (final item in insights)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 14,
              backgroundColor: c.pale,
              child: Icon(Icons.person_outline, size: 16, color: c.petrol)),
            title: Text(item.name, style: TextStyle(color: c.text,
              fontSize: 10, fontWeight: FontWeight.w800)),
            subtitle: Text(_customerTab == 0 ? 'ديون معتمدة: ${_amount(item.debt)}'
              : _customerTab == 1 ? 'التحصيل: ${item.collection}%'
              : 'التغير عن السابق: ${item.change >= 0 ? '+' : ''}${item.change}%',
              style: TextStyle(color: c.muted, fontSize: 8)),
            trailing: Icon(_customerTab == 2
              ? (item.change >= 0 ? Icons.trending_up : Icons.trending_down)
              : Icons.insights_outlined,
              color: _customerTab == 2 && item.change < 0 ? c.success : c.petrol),
          ),
      ]);

  Widget _tab(AppThemeColors c, int index, String text) => Expanded(
    child: TextButton(
      onPressed: () => setState(() => _customerTab = index),
      style: TextButton.styleFrom(
        foregroundColor: _customerTab == index ? c.petrol : c.muted,
        backgroundColor: _customerTab == index ? c.pale : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6)),
      child: Text(text, maxLines: 1,
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800))));

  Widget _alert(AppThemeColors c, String title, String value, Color color) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .2))),
        child: Row(children: [
          Icon(Icons.notifications_active_outlined, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(child: Text(title, style: TextStyle(color: c.text, fontSize: 9))),
          Text(value, style: TextStyle(color: color,
            fontSize: 9, fontWeight: FontWeight.w800)),
        ]));

  Widget _recommendations(AppThemeColors c, Decimal unpaid,
      Decimal pending, int oldPending) => Column(children: [
    if (oldPending > 0)
      _recommendation('راجع الديون المعلقة القديمة وتواصل مع العملاء للتحقق منها.'),
    if (unpaid > _zero)
      _recommendation('تابع تحصيل الرصيد المعتمد المتبقي: ${_amount(unpaid)}.'),
    if (oldPending == 0 && unpaid <= _zero && pending <= _zero)
      _recommendation('لا توجد بيانات كافية لهذه الفترة؛ ستظهر التوصيات عند توفر حركات.'),
    Text('اقتراحات وصفية فقط؛ لا ترسل تذكيراً أو تغيّر حداً ائتمانياً أو تعتمد عملية.',
      style: TextStyle(color: c.muted, fontSize: 8)),
  ]);

  Widget _recommendation(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      gradient: AppGradients.assistant,
      borderRadius: BorderRadius.circular(11)),
    child: Text(text, style: const TextStyle(color: Colors.white,
      fontSize: 9, height: 1.45)));

  Widget _growth(AppThemeColors c, int value) {
    final color = value >= 0 ? c.danger : c.success;
    return Text('${value >= 0 ? '+' : ''}$value%',
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 9));
  }

  Widget _card(AppThemeColors c, String title, IconData icon, Widget child) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF292D55)
              : Colors.white.withValues(alpha: .73),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.cardBorder, width: 1.2),
          boxShadow: PremiumTokens.floatingShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 17, color: c.petrol),
            const SizedBox(width: 7),
            Expanded(child: Text(title, style: TextStyle(color: c.text,
              fontSize: 12, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 10),
          child,
        ]));

}

class _Metric {
  const _Metric(this.title, this.value, this.icon, this.color, this.note);
  final String title;
  final Decimal value;
  final IconData icon;
  final Color color;
  final String note;
}

class _Insight {
  const _Insight(this.name, this.debt, this.collection, this.change);
  final String name;
  final Decimal debt;
  final int collection;
  final int change;
}
