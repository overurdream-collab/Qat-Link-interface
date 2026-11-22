import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:clock/clock.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/premium_tokens.dart';
import '../widgets/customers/customer_statement_calculator.dart';
import '../widgets/customers/customer_statement_pdf.dart';
import '../widgets/finance_display.dart';

/// Customer details body. Lives inside MerchantAppShell so the previously
/// approved top toolbar, night theme, and five-item bottom bar stay visible.
class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.customer,
    required this.state,
    required this.onBack,
    this.merchantId,
    this.initialCurrency = CurrencyCode.yer,
  });

  final CustomerModel customer;
  final AppState state;
  final VoidCallback onBack;
  final String? merchantId;
  final CurrencyCode initialCurrency;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late CurrencyCode _currency;
  MovementStatus? _status;
  late DateTime _from;
  late DateTime _to;
  Uint8List? _temporaryAvatar;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency;
    final today = clock.now();
    _from = DateTime(today.year, 1, 1);
    _to = DateTime(today.year, 12, 31);
  }

  Future<void> _chooseDate(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: start ? 'من تاريخ' : 'إلى تاريخ',
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (start) {
        _from = selected;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = selected;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  Future<void> _changePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 82,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() => _temporaryAvatar = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
          'تم تحديث معاينة الصورة على هذا الجهاز مؤقتاً؛ '
          'الحفظ الدائم يحتاج خدمة الملف الشخصي الموثقة.',
        )),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لم يتم اختيار الصورة. تحقق من إذن الوصول للصور.')),
      );
    }
  }

  Future<void> _createReport(
    CustomerModel customer,
    CustomerStatement statement, {
    required bool share,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (share) {
        await CustomerStatementPdf.share(
            customer: customer,
            statement: statement,
            feminine: context.premium.feminineIdentity);
      } else {
        await CustomerStatementPdf.export(
            customer: customer,
            statement: statement,
            feminine: context.premium.feminineIdentity);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إعداد ملف PDF. $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _statusLabel(MovementStatus status) => switch (status) {
        MovementStatus.approved => 'معتمدة',
        MovementStatus.pending => 'عالقة',
        MovementStatus.rejected => 'مرفوضة',
      };

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
        final candidates = customers.where((e) => e.id == widget.customer.id);
        final customer = candidates.isEmpty ? null : candidates.first;
        final statement = CustomerStatementCalculator.calculate(
          customerId: widget.customer.id,
          merchantId: widget.merchantId,
          currency: _currency,
          from: _from,
          to: _to,
          relationships: widget.state.relationships.value,
          movements: widget.state.movements.value,
          filter: _status,
        );
        return ListView(
          key: const Key('customer_detail_scroll'),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 27),
          children: [
            _pageHeading(c),
            const SizedBox(height: 13),
            if (customer == null ||
                customer.accountStatus != AccountStatus.active ||
                !statement.hasApprovedRelationship) ...[
              _surface(
                  c,
                  Column(
                    children: [
                      Icon(Icons.lock_person_outlined,
                          color: c.muted, size: 30),
                      const SizedBox(height: 9),
                      Text(
                        'تفاصيل العميل غير متاحة لعدم وجود علاقة معتمدة ونشطة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.text, fontSize: 12),
                      ),
                    ],
                  )),
            ] else ...[
              _profile(c, customer),
              const SizedBox(height: 12),
              _period(c),
              const SizedBox(height: 12),
              _currencySection(c),
              const SizedBox(height: 12),
              _statusSection(c),
              const SizedBox(height: 12),
              _transactionsSection(c, statement),
              const SizedBox(height: 12),
              _summarySection(c, statement),
              const SizedBox(height: 13),
              _reportButtons(c, customer, statement),
            ],
          ],
        );
      },
    );
  }

  Widget _pageHeading(AppThemeColors c) => Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: c.pale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              key: const Key('customer_details_back'),
              tooltip: 'العودة للعملاء',
              padding: EdgeInsets.zero,
              icon:
                  Icon(Icons.arrow_forward_rounded, color: c.petrol, size: 19),
              onPressed: widget.onBack,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('بيانات العميل وحركته',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    )),
                Text('إعداد ومراجعة كشف حساب العميل',
                    style: TextStyle(color: c.muted, fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: c.pale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('مقوتي لنك',
                style: TextStyle(
                  color: c.petrol,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ],
      );

  Widget _surface(AppThemeColors c, Widget child) => Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: c.cardBorder),
          boxShadow: AppColors.cardShadow,
        ),
        padding: const EdgeInsets.all(14),
        child: child,
      );

  Widget _sectionHeader(AppThemeColors c, IconData icon, String title) => Row(
        children: [
          Icon(icon, color: c.petrol, size: 16),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                fontSize: 12,
                color: c.petrol,
                fontWeight: FontWeight.w900,
              )),
        ],
      );

  Widget _profile(AppThemeColors c, CustomerModel customer) {
    final rawAddress = customer.profileData['address'];
    final address = rawAddress is String && rawAddress.trim().isNotEmpty
        ? rawAddress
        : 'غير مسجل';
    return _surface(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(c, Icons.person_rounded, 'بيانات العميل'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: c.pale,
                      backgroundImage: _temporaryAvatar == null
                          ? null
                          : MemoryImage(_temporaryAvatar!),
                      child: _temporaryAvatar == null
                          ? Text(
                              customer.name.isEmpty
                                  ? '؟'
                                  : customer.name.substring(0, 1),
                              style: TextStyle(
                                color: c.petrol,
                                fontWeight: FontWeight.w900,
                                fontSize: 21,
                              ))
                          : null,
                    ),
                    Positioned(
                      bottom: -5,
                      left: -4,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: c.card,
                        child: IconButton(
                          key: const Key('customer_avatar_picker'),
                          tooltip: 'تغيير الصورة',
                          padding: EdgeInsets.zero,
                          onPressed: _changePhoto,
                          icon: Icon(Icons.camera_alt_rounded,
                              size: 13, color: c.petrol),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                    child: Column(children: [
                  Row(children: [
                    Expanded(child: _info(c, 'اسم العميل', customer.name)),
                    const SizedBox(width: 8),
                    Expanded(child: _info(c, 'رقم الجوال', customer.phone)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _info(c, 'العنوان', address)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _info(
                            c, 'تاريخ الإضافة', _date(customer.createdAt))),
                  ]),
                ])),
              ],
            ),
          ],
        ));
  }

  Widget _info(AppThemeColors c, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.muted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: c.text,
                fontSize: 11,
              )),
        ],
      );

  Widget _period(AppThemeColors c) => _surface(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(c, Icons.calendar_month_rounded, 'فترة كشف الحساب'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _dateChoice(c, 'من تاريخ', _from, true)),
              const SizedBox(width: 8),
              Expanded(child: _dateChoice(c, 'إلى تاريخ', _to, false)),
            ]),
          ],
        ),
      );

  Widget _dateChoice(
          AppThemeColors c, String title, DateTime value, bool start) =>
      Material(
        color: c.background,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          key: Key(start ? 'statement_from' : 'statement_to'),
          onTap: () => _chooseDate(start),
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: c.cardBorder),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(children: [
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 10,
                      )),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_date(value),
                        style: TextStyle(
                          color: c.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                ],
              )),
              Icon(Icons.date_range_outlined, size: 15, color: c.petrol),
            ]),
          ),
        ),
      );

  Widget _currencySection(AppThemeColors c) => _surface(
      c,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(c, Icons.currency_exchange_rounded, 'العملة'),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CurrencyCode.values.length,
              separatorBuilder: (context, index) => const SizedBox(width: 9),
              itemBuilder: (context, i) {
                final currency = CurrencyCode.values[i];
                final selected = _currency == currency;
                return InkWell(
                  key: Key('statement_currency_${currency.name}'),
                  onTap: () => setState(() => _currency = currency),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 139,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: selected ? c.pale : c.card,
                      border: Border.all(
                        color: selected ? c.petrol : c.cardBorder,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            currency == CurrencyCode.yer
                                ? 'العملة الافتراضية'
                                : currency == CurrencyCode.sar
                                    ? 'عملة خليجية'
                                    : 'عملة دولية',
                            style: TextStyle(color: c.muted, fontSize: 9)),
                        const SizedBox(height: 5),
                        Text(FinanceDisplay.currencyName(currency),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            )),
                        const Spacer(),
                        Text(FinanceDisplay.currencyCode(currency),
                            style: TextStyle(
                              color: c.petrol,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final currency in CurrencyCode.values) ...[
                Container(
                  height: 7,
                  width: currency == _currency ? 16 : 7,
                  decoration: BoxDecoration(
                    color: currency == _currency ? c.petrol : c.cardBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 5),
              ],
            ],
          ),
        ],
      ));

  Widget _statusSection(AppThemeColors c) {
    const filters = <(MovementStatus?, String)>[
      (null, 'جميع العمليات'),
      (MovementStatus.approved, 'المعتمدة'),
      (MovementStatus.pending, 'العالقة'),
      (MovementStatus.rejected, 'المرفوضة'),
    ];
    return _surface(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(c, Icons.filter_list_rounded, 'نوع الكشف'),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final active = _status == filter.$1;
                  return Material(
                    color: active ? c.petrol : c.background,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      key: Key('statement_filter_${filter.$1?.name ?? 'all'}'),
                      onTap: () => setState(() => _status = filter.$1),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: active ? c.petrol : c.cardBorder,
                          ),
                        ),
                        child: Text(filter.$2,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: active
                                  ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.darkBackground
                                      : Colors.white)
                                  : c.text,
                            )),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ));
  }

  Widget _transactionsSection(AppThemeColors c, CustomerStatement statement) =>
      _surface(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('تفاصيل العمليات',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: c.pale,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${statement.visibleCount} عمليات',
                    style: TextStyle(
                      color: c.petrol,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 700,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: c.pale,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _transactionCells(
                        c,
                        [
                          'التاريخ',
                          'البيان أو الوصف',
                          'النوع',
                          'المبلغ',
                          'الحالة'
                        ],
                        header: true,
                      ),
                    ),
                    if (statement.rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(19),
                        child: Text(
                          'لا توجد عمليات تطابق خيارات الكشف المحددة.',
                          style: TextStyle(color: c.muted, fontSize: 11),
                        ),
                      ),
                    for (final movement in statement.rows)
                      _transactionRow(c, movement),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _transactionCells(
    AppThemeColors c,
    List<String> values, {
    bool header = false,
    List<Color>? colors,
  }) {
    final widths = [105.0, 228.0, 78.0, 150.0, 130.0];
    return Row(
      children: [
        for (var i = 0; i < values.length; i++)
          SizedBox(
            width: widths[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 11,
              ),
              child: Text(
                values[i],
                maxLines: header ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      header ? c.petrol : (colors == null ? c.text : colors[i]),
                  fontWeight: header ? FontWeight.w900 : FontWeight.w600,
                  fontSize: header ? 11 : 10,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _transactionRow(AppThemeColors c, MovementModel m) {
    final type = m.type == MovementType.debt;
    final stateColor = m.status == MovementStatus.approved
        ? c.success
        : m.status == MovementStatus.pending
            ? c.pendingText
            : c.danger;
    return Column(
      children: [
        _transactionCells(
          c,
          [
            _date(m.createdAt),
            m.description?.trim().isNotEmpty == true
                ? m.description!
                : (type ? 'تسجيل دين' : 'تسديد'),
            type ? 'دين' : 'تسديد',
            '${FinanceDisplay.amount(m.amount)} ${FinanceDisplay.currencyCode(m.currency)}',
            _statusLabel(m.status),
          ],
          colors: [
            c.muted,
            c.text,
            c.text,
            type ? c.danger : c.success,
            stateColor,
          ],
        ),
        Divider(height: 1, color: c.cardBorder),
      ],
    );
  }

  Widget _summarySection(AppThemeColors c, CustomerStatement statement) {
    final stats = <(String, Decimal, Color)>[
      ('إجمالي الديون المعتمدة', statement.approvedDebts, c.danger),
      ('إجمالي التحصيل المعتمد', statement.approvedPayments, c.success),
      ('إجمالي العمليات العالقة', statement.pendingAmount, c.pendingText),
      ('الرصيد الختامي المعتمد', statement.closingBalance, c.petrol),
    ];
    return _surface(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(c, Icons.pie_chart_outline_rounded, 'الملخص المالي'),
            const SizedBox(height: 8),
            Text(
              'الرصيد الافتتاحي: ${FinanceDisplay.amount(statement.openingBalance)} '
              '${FinanceDisplay.currencyCode(statement.currency)}',
              style: TextStyle(color: c.muted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                for (final item in stats)
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: item.$3 == c.petrol ? c.pale : c.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1,
                            maxLines: 2,
                            style: TextStyle(color: c.muted, fontSize: 10)),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${FinanceDisplay.amount(item.$2)} '
                            '${FinanceDisplay.currencyCode(statement.currency)}',
                            style: TextStyle(
                              color: item.$3,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'المؤشرات لجميع حالات الفترة؛ تصفية الجدول لا تغيّر الرصيد. '
              'المعلق والمرفوض لا يدخلان في الرصيد الختامي.',
              style: TextStyle(color: c.muted, fontSize: 10, height: 1.5),
            ),
          ],
        ));
  }

  Widget _reportButtons(AppThemeColors c, CustomerModel customer,
          CustomerStatement statement) =>
      Row(children: [
        Expanded(
            child: Container(
          decoration: BoxDecoration(
            gradient: context.premium.accessibleAction,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FilledButton.icon(
            key: const Key('statement_export_pdf'),
            onPressed: _busy
                ? null
                : () => _createReport(customer, statement, share: false),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(_busy ? 'جارٍ الإعداد' : 'تصدير PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              minimumSize: const Size.fromHeight(47),
            ),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton.icon(
          key: const Key('statement_share_pdf'),
          onPressed: _busy
              ? null
              : () => _createReport(customer, statement, share: true),
          icon: Icon(Icons.share_outlined, color: c.petrol, size: 17),
          label: const Text('مشاركة الكشف'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.petrol,
            side: BorderSide(color: c.mint),
            minimumSize: const Size.fromHeight(47),
          ),
        )),
      ]);
}
