import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../models/app_models.dart';
import '../models/merchant_pending_models.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/finance_display.dart';
import '../widgets/customers/merchant_pending_statement_pdf.dart';

class _PendingEntryDraft {
  const _PendingEntryDraft(this.amount, this.currency, this.description);
  final Decimal amount;
  final CurrencyCode currency;
  final String? description;
}

class MerchantPendingContactDetailsScreen extends StatefulWidget {
  const MerchantPendingContactDetailsScreen({
    super.key,
    required this.state,
    required this.contact,
    required this.merchantId,
  });

  final AppState state;
  final MerchantPendingContact contact;
  final String? merchantId;

  @override
  State<MerchantPendingContactDetailsScreen> createState() =>
      _MerchantPendingContactDetailsScreenState();
}

class _MerchantPendingContactDetailsScreenState
    extends State<MerchantPendingContactDetailsScreen> {
  bool _reportBusy = false;

  Future<_PendingEntryDraft?> _entryDialog({required bool payment}) async {
    final formKey = GlobalKey<FormState>();
    final amount = TextEditingController();
    final description = TextEditingController();
    var currency = CurrencyCode.yer;
    try {
      return await showDialog<_PendingEntryDraft>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: Text(payment ? 'تسجيل دفعة للعميل' : 'تسجيل دين للعميل'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    payment
                        ? 'تُسجل الدفعة في سجل التاجر وتخفض صافي المديونية التشغيلي. '
                            'تبقى معلقة ولا تخفض الرصيد المشترك المعتمد.'
                        : 'يُسجل الدين في دفتر التاجر وحده ويبقى معلقاً حتى يراجع العميل العملية.',
                    style: TextStyle(
                        color: dialogContext.colors.muted,
                        fontSize: 11,
                        height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('off_app_entry_amount'),
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'المبلغ'),
                    validator: (value) {
                      final clean = _normalizeAmount(value ?? '');
                      if (!RegExp(r'^\d{1,16}(?:\.\d{1,4})?$')
                          .hasMatch(clean)) {
                        return 'أدخل مبلغاً موجباً بدقة تصل إلى 4 منازل';
                      }
                      if (Decimal.parse(clean) <= Decimal.zero) {
                        return 'المبلغ يجب أن يكون أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<CurrencyCode>(
                    key: const Key('off_app_entry_currency'),
                    value: currency,
                    decoration: const InputDecoration(labelText: 'العملة'),
                    items: [
                      for (final unit in CurrencyCode.values)
                        DropdownMenuItem(
                          value: unit,
                          child: Text(unit.name.toUpperCase()),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) update(() => currency = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('off_app_entry_description'),
                    controller: description,
                    maxLength: 160,
                    decoration:
                        const InputDecoration(labelText: 'البيان (اختياري)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                key: const Key('off_app_entry_save'),
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(
                    dialogContext,
                    _PendingEntryDraft(
                      Decimal.parse(_normalizeAmount(amount.text)),
                      currency,
                      description.text.trim().isEmpty
                          ? null
                          : description.text.trim(),
                    ),
                  );
                },
                child: const Text('حفظ في سجل التاجر'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amount.dispose();
      description.dispose();
    }
  }

  String _normalizeAmount(String input) => input
      .replaceAllMapped(RegExp(r'[٠-٩]'), (match) =>
          String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0x0660 + 0x30))
      .replaceAllMapped(RegExp(r'[۰-۹]'), (match) =>
          String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0x06F0 + 0x30))
      .replaceAll('٫', '.')
      .replaceAll(',', '')
      .trim();

  Future<void> _saveEntry({required bool payment}) async {
    final merchantId = widget.merchantId;
    if (merchantId == null || merchantId != widget.contact.merchantId) {
      _message('هوية التاجر غير موثقة؛ لا يمكن حفظ حركة لهذا السجل.');
      return;
    }
    final draft = await _entryDialog(payment: payment);
    if (draft == null || !mounted) return;
    final id = 'local-${payment ? 'payment' : 'debt'}-'
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${payment ? widget.state.merchantPendingPayments.value.length : widget.state.merchantPendingDebts.value.length}';
    try {
      if (payment) {
        widget.state.addMerchantPendingPayment(MerchantPendingPayment(
          id: id,
          merchantId: merchantId,
          contactId: widget.contact.id,
          amount: draft.amount,
          currency: draft.currency,
          createdAt: DateTime.now(),
          description: draft.description,
        ));
      } else {
        widget.state.addMerchantPendingDebt(MerchantPendingDebt(
          id: id,
          merchantId: merchantId,
          contactId: widget.contact.id,
          amount: draft.amount,
          currency: draft.currency,
          createdAt: DateTime.now(),
          description: draft.description,
        ));
      }
      _message(payment
          ? 'سُجلت الدفعة في سجل التاجر؛ لم تغيّر الرصيد المشترك المعتمد.'
          : 'سُجل الدين في سجل التاجر؛ ينتظر انضمام العميل ومراجعته.');
    } on Object {
      _message('تعذر حفظ الحركة. تحقق من سجل العميل والعملة والمبلغ.');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _copyStatement() async {
    try {
      final statement = widget.state.merchantPendingStatement(
        merchantId: widget.merchantId,
        contactId: widget.contact.id,
        from: DateTime(2000),
        to: DateTime.now(),
      );
      await Clipboard.setData(ClipboardData(
          text: MerchantPendingDebtQuery.shareText(statement)));
      if (mounted) {
        _message('نُسخ كشف سجل التاجر. راجع اسم المستلم قبل مشاركته.');
      }
    } on Object {
      if (mounted) _message('تعذر إعداد الكشف من السجل الحالي.');
    }
  }

  Future<void> _exportStatement({required bool share}) async {
    if (_reportBusy) return;
    setState(() => _reportBusy = true);
    try {
      final statement = widget.state.merchantPendingStatement(
        merchantId: widget.merchantId,
        contactId: widget.contact.id,
        from: DateTime(2000),
        to: DateTime.now(),
      );
      final bytes = await MerchantPendingStatementPdf.create(statement);
      final safeId = widget.contact.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filename = 'maqwati_unverified_statement_$safeId.pdf';
      final completed = share
          ? await Printing.sharePdf(bytes: bytes, filename: filename)
          : await Printing.layoutPdf(
              name: filename,
              onLayout: (_) async => bytes,
            );
      if (mounted && !share && !completed) {
        _message('لم يكتمل تصدير الكشف.');
      }
    } on Object {
      if (mounted) _message('تعذر تجهيز كشف PDF من سجل التاجر.');
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملف عميل خارج التطبيق',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          widget.state.merchantPendingDebts,
          widget.state.merchantPendingPayments,
        ]),
        builder: (context, _) {
          final debts = widget.state.merchantPendingDebts.value.where((entry) =>
              entry.merchantId == widget.merchantId &&
              entry.contactId == widget.contact.id);
          final payments = widget.state.merchantPendingPayments.value
              .where((entry) =>
                  entry.merchantId == widget.merchantId &&
                  entry.contactId == widget.contact.id);
          final debtTotals = _totals(debts);
          final paymentTotals = _totals(payments);
          final rows = <_TimelineEntry>[
            for (final debt in debts)
              _TimelineEntry(
                id: debt.id,
                amount: debt.amount,
                currency: debt.currency,
                createdAt: debt.createdAt,
                description: debt.description,
                isPayment: false,
              ),
            for (final payment in payments)
              _TimelineEntry(
                id: payment.id,
                amount: payment.amount,
                currency: payment.currency,
                createdAt: payment.createdAt,
                description: payment.description,
                isPayment: true,
              ),
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppSurface(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: c.pale,
                      child: Icon(Icons.person_outline_rounded,
                          color: c.petrol, size: 27),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.contact.name,
                              style: TextStyle(
                                  color: c.text,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const SizedBox(height: 3),
                          Text(widget.contact.phone,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(color: c.muted, fontSize: 12)),
                          const SizedBox(height: 5),
                          Text('خارج التطبيق — بانتظار الانضمام',
                              style: TextStyle(
                                  color: c.pendingText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.pendingBackground,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Text(
                  'هذا سجل التاجر وحده. الديون والدفعات فيه معلقة وغير معتمدة من العميل، '
                  'ولا تدخل الرصيد المشترك المعتمد.',
                  style: TextStyle(color: c.pendingText, fontSize: 11, height: 1.5),
                ),
              ),
              const SizedBox(height: 14),
              AppSectionTitle(title: 'الملخص حسب العملة'),
              const SizedBox(height: 8),
              for (final currency in CurrencyCode.values)
                _currencySummary(
                  c,
                  currency,
                  debtTotals[currency] ?? Decimal.zero,
                  paymentTotals[currency] ?? Decimal.zero,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('off_app_add_debt'),
                      onPressed: () => _saveEntry(payment: false),
                      icon: const Icon(Icons.add_card_outlined),
                      label: const Text('تسجيل دين'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('off_app_add_payment'),
                      onPressed: () => _saveEntry(payment: true),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('تسجيل دفعة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('off_app_copy_statement'),
                onPressed: rows.isEmpty ? null : _copyStatement,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('نسخ كشف الحركة للمشاركة'),
              ),
              const SizedBox(height: 7),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  key: const Key('off_app_export_pdf'),
                  onPressed: rows.isEmpty || _reportBusy
                      ? null : () => _exportStatement(share: false),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(_reportBusy ? 'جارٍ التجهيز' : 'تصدير PDF'),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  key: const Key('off_app_share_pdf'),
                  onPressed: rows.isEmpty || _reportBusy
                      ? null : () => _exportStatement(share: true),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('مشاركة PDF'),
                )),
              ]),
              const SizedBox(height: 17),
              AppSectionTitle(
                title: 'سجل الحركة',
                trailing: Text('${rows.length} عملية',
                    style: TextStyle(color: c.muted, fontSize: 10)),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                AppSurface(
                  padding: const EdgeInsets.all(22),
                  child: Text('لا توجد حركات مسجلة لهذا العميل بعد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, fontSize: 12)),
                )
              else
                for (final row in rows) _timelineRow(c, row),
            ],
          );
        },
      ),
    );
  }

  Map<CurrencyCode, Decimal> _totals<T extends Object>(Iterable<T> entries) {
    final totals = <CurrencyCode, Decimal>{};
    for (final entry in entries) {
      final currency = switch (entry) {
        MerchantPendingDebt debt => debt.currency,
        MerchantPendingPayment payment => payment.currency,
        _ => throw StateError('Unsupported pending movement type.'),
      };
      final amount = switch (entry) {
        MerchantPendingDebt debt => debt.amount,
        MerchantPendingPayment payment => payment.amount,
        _ => Decimal.zero,
      };
      totals.update(currency, (value) => value + amount,
          ifAbsent: () => amount);
    }
    return totals;
  }

  Widget _currencySummary(
    AppThemeColors c,
    CurrencyCode currency,
    Decimal debts,
    Decimal payments,
  ) {
    final net = debts - payments;
    final symbol = FinanceDisplay.currencySymbol(currency);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: AppSurface(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currency.name.toUpperCase(),
                style: TextStyle(
                    color: c.petrol, fontWeight: FontWeight.w900, fontSize: 11)),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(child: _summaryValue(c, 'الديون المسجلة', debts, symbol)),
                Expanded(child: _summaryValue(c, 'الدفعات المسجلة', payments, symbol)),
                Expanded(
                  child: _summaryValue(
                    c,
                    net < Decimal.zero ? 'رصيد تشغيلي دائن' : 'صافي تشغيلي',
                    net,
                    symbol,
                    valueColor: net < Decimal.zero ? c.success : c.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryValue(
    AppThemeColors c,
    String title,
    Decimal value,
    String symbol, {
    Color? valueColor,
  }) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 2,
              style: TextStyle(color: c.muted, fontSize: 9, height: 1.3)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${FinanceDisplay.amount(value)} $symbol',
              style: TextStyle(
                  color: valueColor ?? c.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );

  Widget _timelineRow(AppThemeColors c, _TimelineEntry row) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: AppSurface(
          key: ValueKey('pending_entry_${row.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                row.isPayment
                    ? Icons.payments_outlined
                    : Icons.receipt_long_outlined,
                color: row.isPayment ? c.success : c.pendingText,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.isPayment ? 'دفعة مسجلة' : 'دين مسجل',
                        style: TextStyle(
                            color: c.text, fontWeight: FontWeight.w800)),
                    Text(
                      '${row.createdAt.year}/${row.createdAt.month.toString().padLeft(2, '0')}/${row.createdAt.day.toString().padLeft(2, '0')}'
                      '${row.description == null ? '' : ' • ${row.description}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 10),
                    ),
                    Text('معلق — بانتظار انضمام العميل',
                        style: TextStyle(color: c.pendingText, fontSize: 9)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${row.isPayment ? '−' : '+'}${FinanceDisplay.amount(row.amount)} '
                '${FinanceDisplay.currencySymbol(row.currency)}',
                style: TextStyle(
                    color: row.isPayment ? c.success : c.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 11),
              ),
            ],
          ),
        ),
      );
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.id,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.description,
    required this.isPayment,
  });

  final String id;
  final Decimal amount;
  final CurrencyCode currency;
  final DateTime createdAt;
  final String? description;
  final bool isPayment;
}
