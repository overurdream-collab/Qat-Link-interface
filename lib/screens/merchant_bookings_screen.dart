import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/finance_display.dart';
import '../widgets/merchant_space/booking_debt_planner.dart';
import '../widgets/merchant_space/merchant_space_models.dart';
import '../widgets/merchant_space/worker_preparation_pdf.dart';

/// A dedicated booking management body. The merchant shell keeps its
/// approved global header, night mode, and bottom navigation.
class MerchantBookingsScreen extends StatefulWidget {
  const MerchantBookingsScreen({
    super.key,
    required this.bookings,
    required this.day,
    required this.onDayChanged,
    required this.onAddBooking,
    required this.onUpdateBooking,
    required this.onBack,
    required this.state,
    required this.storeName,
    this.merchantId,
  });

  final List<ReservationDraft> bookings;
  final DateTime day;
  final ValueChanged<DateTime> onDayChanged;
  final VoidCallback onAddBooking;
  final void Function(String id, ReservationStatus status) onUpdateBooking;
  final VoidCallback onBack;
  final AppState state;
  final String storeName;
  final String? merchantId;

  @override
  State<MerchantBookingsScreen> createState() => _MerchantBookingsScreenState();
}

class _MerchantBookingsScreenState extends State<MerchantBookingsScreen> {
  final Set<String> _selectedIds = {};
  bool _exporting = false;

  Future<void> _selectDate() async {
    final newDate = await showDatePicker(
      context: context, initialDate: widget.day,
      firstDate: DateTime(2025), lastDate: DateTime(2100),
      helpText: 'اختر يوم الحجوزات والمبيعات',
    );
    if (mounted && newDate != null) {
      setState(() => _selectedIds.clear());
      widget.onDayChanged(newDate);
    }
  }

  Future<void> _workersReport({required bool share}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final summary = ReservationsQuery.forDay(widget.bookings, widget.day);
      final bytes = await WorkerPreparationPdf.generate(
        day: widget.day, storeName: widget.storeName, summary: summary);
      if (share) {
        await WorkerPreparationPdf.share(bytes, widget.day);
      } else {
        await WorkerPreparationPdf.print(bytes, widget.day);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إنشاء كشف العمال أو مشاركته.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  BookingDebtPlan _plan(Iterable<ReservationDraft> orders, Set<String> ids) =>
      BookingDebtPlanner.build(
        merchantId: widget.merchantId,
        bookings: orders,
        selectedIds: ids,
        relationships: widget.state.relationships.value,
        customers: widget.state.customers.value,
      );

  Future<void> _reviewDebtConversion(
      List<ReservationDraft> currentOrders) async {
    final plan = _plan(currentOrders, _selectedIds);
    final c = context.colors;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.viewInsetsOf(sheet).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('مراجعة التحويل الجماعي إلى ديون',
                  style: TextStyle(
                    color: c.petrol, fontSize: 18,
                    fontWeight: FontWeight.w900,
                  )),
                const SizedBox(height: 7),
                Text(
                  'تم تحديد ${_selectedIds.length} حجز • '
                  '${plan.includedBookings} صالح للتحويل • '
                  '${plan.skipped.length} مستبعد',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                for (final req in plan.requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.pale,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عميل: ${_customerName(req.customerId)}',
                            style: TextStyle(color: c.text,
                              fontWeight: FontWeight.w800)),
                          Text(
                            '${req.bookingIds.length} حجز • '
                            '${FinanceDisplay.amount(req.amount)} '
                            '${FinanceDisplay.currencyCode(req.currency)}',
                            style: TextStyle(color: c.petrol,
                              fontWeight: FontWeight.w900)),
                          Text('طلب دين مستقل بانتظار موافقة هذا العميل',
                            style: TextStyle(color: c.muted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                if (plan.skipped.isNotEmpty) ...[
                  Text('حجوزات لم تُضمّن', style: TextStyle(
                    color: c.danger, fontWeight: FontWeight.w900)),
                  for (final entry in plan.skipped.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: TextStyle(color: c.muted, fontSize: 11),
                      ),
                    ),
                ],
                if (plan.requests.isEmpty)
                  Text('لا توجد حجوزات مؤهلة للتحويل إلى ديون.',
                      style: TextStyle(color: c.muted)),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.cardBorder),
                  ),
                  child: Text(
                    'هذه معاينة فقط. إرسال الطلبات دفعة واحدة يحتاج '
                    'خادمًا موثقًا، ومنع تكرار الحجز، وموافقة كل عميل '
                    'على طلبه. لن تُنشأ أي حركة مالية الآن.',
                    style: TextStyle(
                      color: c.pendingText, fontSize: 12, height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('booking_batch_close'),
                  onPressed: () => Navigator.of(sheet).pop(),
                  child: const Text('إغلاق المراجعة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _customerName(String id) {
    for (final customer in widget.state.customers.value) {
      if (customer.id == id) return customer.name;
    }
    return 'عميل مرتبط';
  }

  String _date(DateTime day) =>
      '${day.year}/${day.month.toString().padLeft(2, '0')}/'
      '${day.day.toString().padLeft(2, '0')}';

  Widget _metric(AppThemeColors c, String value, String title) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.cardBorder)),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              color: c.petrol, fontSize: 20,
              fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(title, style: TextStyle(
              color: c.muted, fontSize: 10),
              textAlign: TextAlign.center),
          ],
        ),
      ));

  Widget _bookingCard(AppThemeColors c, ReservationDraft order) {
    final amount = order.saleTotal;
    return Container(
      key: Key('bookings_screen_row_${order.id}'),
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Checkbox(
          key: Key('bookings_select_${order.id}'),
          value: _selectedIds.contains(order.id),
          onChanged: (checked) => setState(() {
            if (checked == true) {
              _selectedIds.add(order.id);
            } else {
              _selectedIds.remove(order.id);
            }
          }),
        ),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.customerName, style: TextStyle(
              fontWeight: FontWeight.w900, color: c.text, fontSize: 13)),
            const SizedBox(height: 3),
            Text(
              '${order.item} • ${order.bundles} ربطة • ${order.pickupTime}',
              style: TextStyle(color: c.muted, fontSize: 11)),
            const SizedBox(height: 3),
            Text(
              amount == null
                ? 'السعر غير محدد'
                : '${FinanceDisplay.amount(amount)} '
                  '${FinanceDisplay.currencyCode(order.currency)}'
                  ' • ${order.settlement == BookingSettlement.paid ? 'مسدد' : order.settlement == BookingSettlement.unpaid ? 'غير مسدد' : 'السداد غير محدد'}',
              style: TextStyle(color: c.petrol, fontSize: 11)),
          ],
        )),
        PopupMenuButton<ReservationStatus>(
          tooltip: 'تحديث حالة الحجز',
          onSelected: (status) => widget.onUpdateBooking(order.id, status),
          itemBuilder: (_) => [
            for (final status in ReservationStatus.values)
              PopupMenuItem(value: status, child: Text(status.label)),
          ],
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.pale, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(order.status.label,
                  style: TextStyle(color: c.petrol,
                    fontWeight: FontWeight.w800, fontSize: 10)),
                Icon(Icons.expand_more_rounded, color: c.petrol, size: 18),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final day = widget.day;
    final summary = ReservationsQuery.forDay(widget.bookings, day);
    final sales = BookingSalesQuery.calculate(widget.bookings, day);
    final qualified = summary.orders.where((b) =>
      _plan([b], {b.id}).includedBookings > 0).map((b) => b.id).toSet();

    return ListView(
      key: const Key('merchant_bookings_scroll'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Row(children: [
          IconButton(
            key: const Key('bookings_back_to_space'),
            tooltip: 'العودة إلى مساحتي',
            onPressed: widget.onBack,
            icon: Icon(Icons.arrow_forward_rounded, color: c.petrol)),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إدارة الحجوزات', style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w900, color: c.text)),
              Text('التجهيز والمبيعات في كشف واحد',
                style: TextStyle(fontSize: 11, color: c.muted)),
            ],
          )),
          Icon(Icons.inventory_2_outlined, color: c.petrol, size: 29),
        ]),
        const SizedBox(height: 12),
        AppSurface(child: Column(children: [
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              key: const Key('bookings_choose_date'),
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(_date(day)),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(
              key: const Key('bookings_add'),
              onPressed: widget.onAddBooking,
              icon: const Icon(Icons.add_rounded),
              label: const Text('حجز سريع'),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _metric(c, '${summary.activeCount}', 'طلب للتجهيز'),
            const SizedBox(width: 8),
            _metric(c, '${summary.totalBundles}', 'ربطة مطلوبة'),
            const SizedBox(width: 8),
            _metric(c, '${sales.collectedCount}', 'تم استلامه'),
          ]),
        ])),
        const SizedBox(height: 12),
        AppSurface(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('كشف العمال', style: TextStyle(
              color: c.petrol, fontSize: 16,
              fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('خط عربي كبير، وبيانات التجهيز فقط: الاسم، الصنف، العدد والوقت.',
              style: TextStyle(color: c.muted, fontSize: 11)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton.icon(
                key: const Key('workers_share_pdf'),
                onPressed: _exporting ? null : () => _workersReport(share: true),
                icon: const Icon(Icons.share_outlined),
                label: const Text('مشاركة مع العمال'),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                key: const Key('workers_print_pdf'),
                onPressed: _exporting ? null : () => _workersReport(share: false),
                icon: const Icon(Icons.print_outlined),
                label: const Text('طباعة الكشف'),
              )),
            ]),
          ],
        )),
        const SizedBox(height: 12),
        AppSurface(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المبيعات اليومية', style: TextStyle(
              color: c.petrol, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('المبيعات المسجلة كطلبات مستلمة مع سعر محدد؛ '
                'هذه ليست أرصدة الديون.',
              style: TextStyle(color: c.muted, fontSize: 11)),
            const SizedBox(height: 9),
            for (final currency in CurrencyCode.values) ...[
              Row(children: [
                Text(FinanceDisplay.currencyCode(currency),
                  style: TextStyle(color: c.text,
                      fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(FinanceDisplay.amount(
                  sales.byCurrency[currency] ?? Decimal.zero),
                  style: TextStyle(color: c.petrol, fontSize: 15,
                    fontWeight: FontWeight.w900)),
              ]),
              Divider(color: c.cardBorder, height: 13),
            ],
            if (sales.missingPriceCount > 0)
              Text('${sales.missingPriceCount} عملية مستلمة بلا سعر، '
                  'ولا تدخل في إجمالي المبيعات.',
                  style: TextStyle(color: c.danger, fontSize: 10)),
            Text('التحصيل النقدي والديون حسابات مستقلة تحتاج توثيق الخادم.',
                style: TextStyle(color: c.muted, fontSize: 10)),
          ],
        )),
        const SizedBox(height: 12),
        AppSurface(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('حجوزات الفترة',
                style: TextStyle(color: c.text,
                  fontSize: 15, fontWeight: FontWeight.w900))),
              TextButton(
                key: const Key('bookings_select_all_eligible'),
                onPressed: () => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(qualified);
                }),
                child: const Text('تحديد المؤهل'),
              ),
            ]),
            const SizedBox(height: 4),
            if (summary.orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('لا توجد حجوزات لهذا التاريخ.',
                  style: TextStyle(color: c.muted)),
              ),
            for (final order in summary.orders)
              _bookingCard(c, order),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: FilledButton.icon(
                key: const Key('bookings_batch_debt'),
                onPressed: _selectedIds.isEmpty
                    ? null : () => _reviewDebtConversion(summary.orders),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text('مراجعة تحويل ${_selectedIds.length} حجز إلى ديون'),
              ),
            ),
            const SizedBox(height: 8),
            Text('تُنشأ عند الربط طلبات منفصلة لكل عميل وعملة؛ '
                'لا دين معتمداً قبل موافقة العميل.',
              style: TextStyle(color: c.muted, fontSize: 10)),
          ],
        )),
      ],
    );
  }
}
