import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/finance_display.dart';
import '../widgets/merchant_space/booking_debt_planner.dart';
import '../widgets/merchant_space/booking_intake_policy.dart';
import '../widgets/merchant_space/night_reminder_campaign.dart';
import '../widgets/merchant_space/daily_debt_query.dart';
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
    this.intakeSettings = const BookingIntakeSettings(),
    this.onIntakeSettingsChanged,
    this.reminderSettings = const BookingNightReminderSettings(),
    this.onReminderSettingsChanged,
    this.verifiedNotificationOptInCustomerIds = const <String>{},
    this.verifiedFavoriteCustomerIds = const <String>{},
    this.verifiedReminderEvents,
    this.verifiedReminderCampaignId,
    this.verifiedReminderRecipientIds = const <String>{},
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
  final BookingIntakeSettings intakeSettings;
  final ValueChanged<BookingIntakeSettings>? onIntakeSettingsChanged;
  final BookingNightReminderSettings reminderSettings;
  final ValueChanged<BookingNightReminderSettings>? onReminderSettingsChanged;
  /// Verified opt-ins from a server-backed preference service (not a local guess).
  final Set<String> verifiedNotificationOptInCustomerIds;
  /// Verified merchant-owned favorites, never generated from local text fields.
  final Set<String> verifiedFavoriteCustomerIds;
  /// Server telemetry for a sent campaign; null means analytics unavailable.
  final List<ReminderEngagementEvent>? verifiedReminderEvents;
  final String? verifiedReminderCampaignId;
  final Set<String> verifiedReminderRecipientIds;

  @override
  State<MerchantBookingsScreen> createState() => _MerchantBookingsScreenState();
}

class _MerchantBookingsScreenState extends State<MerchantBookingsScreen> {
  final Set<String> _selectedIds = {};
  bool _exporting = false;
  late BookingIntakeSettings _settings;
  late BookingNightReminderSettings _reminder;
  NightReminderAudience _audience = NightReminderAudience.allApproved;
  final TextEditingController _offeredItem = TextEditingController();
  String _pickupTime = '11:00';

  @override
  void initState() {
    super.initState();
    _settings = widget.intakeSettings;
    _reminder = widget.reminderSettings;
  }

  @override
  void dispose() {
    _offeredItem.dispose();
    super.dispose();
  }

  Future<void> _pickCampaignPickupTime() async {
    final parts = _pickupTime.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      helpText: 'موعد استلام الطلب من التذكير',
    );
    if (mounted && selected != null) {
      setState(() => _pickupTime = _clock(
        selected.hour * 60 + selected.minute));
    }
  }

  List<String> _audiencePreview() => NightReminderAudienceQuery.recipients(
    audience: _audience,
    merchantId: widget.merchantId,
    now: DateTime.now(),
    customers: widget.state.customers.value,
    relationships: widget.state.relationships.value,
    bookings: widget.bookings,
    consentedCustomerIds: widget.verifiedNotificationOptInCustomerIds,
    merchantFavoriteCustomerIds: widget.verifiedFavoriteCustomerIds,
    settings: _reminder,
  );

  void _setSettings(BookingIntakeSettings next) {
    setState(() => _settings = next);
    widget.onIntakeSettingsChanged?.call(next);
  }

  void _setReminder(BookingNightReminderSettings next) {
    setState(() => _reminder = next);
    widget.onReminderSettingsChanged?.call(next);
  }

  static String _clock(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickIntakeTime(bool start) async {
    final current = start ? _settings.opensAtMinute : _settings.closesAtMinute;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: start ? 'بداية استقبال الحجوزات' : 'نهاية استقبال الحجوزات',
    );
    if (!mounted || selected == null) return;
    final minute = selected.hour * 60 + selected.minute;
    final next = start
        ? _settings.copyWith(opensAtMinute: minute)
        : _settings.copyWith(closesAtMinute: minute);
    if (!next.valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد وقتين مختلفين أو فعّل نظام 24 ساعة.')),
      );
      return;
    }
    _setSettings(next);
  }

  Future<void> _pickReminderTime() async {
    final minute = _reminder.sendAtMinute;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      helpText: 'وقت التذكير الليلي بتوقيت صنعاء',
    );
    if (!mounted || selected == null) return;
    _setReminder(_reminder.copyWith(
      sendAtMinute: selected.hour * 60 + selected.minute));
  }

  void _previewReminder() {
    final eligible = _audiencePreview();
    final preview = BookingNightReminderPolicy.preview(
      settings: _reminder,
      merchantId: widget.merchantId,
      customers: widget.state.customers.value,
      relationships: widget.state.relationships.value,
      consentedCustomerIds: widget.verifiedNotificationOptInCustomerIds,
      now: DateTime.now(),
    );
    final campaign = NightReminderCampaignDraft(
      id: 'preview-only',
      merchantId: widget.merchantId ?? '',
      day: preview.bookingForDay,
      audience: _audience,
      offeredItem: _offeredItem.text.trim(),
      pickupTime: _pickupTime,
    );
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: c.card,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('معاينة تذكير حجوزات الغد', style: TextStyle(
                color: c.petrol, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 9),
              Text('الفئة: ${_audience.label}', style: TextStyle(color: c.text)),
              Text('العملاء الموافقون على التذكير: ${eligible.length}',
                  style: TextStyle(color: c.petrol)),
              Text('الساعة: ${_clock(_reminder.sendAtMinute)} بتوقيت صنعاء',
                style: TextStyle(color: c.muted)),
              const SizedBox(height: 11),
              Text('عملاءنا الكرام، احجزوا ${campaign.offeredItem} '
                  'للغد. موعد الاستلام: ${campaign.pickupTime}.',
                style: TextStyle(color: c.text, height: 1.55)),
              const SizedBox(height: 9),
              Text('عند فتح التذكير يظهر للعميل: «تأكيد الحجز» أو '
                  '«تجاهل». التأكيد يفتح اختيار عدد الربطات فقط.',
                style: TextStyle(color: c.petrol, fontSize: 12,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('معاينة محلية فقط. لا يوجد إرسال أو جدولة ولا بيانات '
                'قراءة مؤكدة دون خادم موثق. ستُطبّق صلاحيات الباقة '
                'وقت التشغيل بعد اعتماد الباقات.',
                style: TextStyle(color: c.pendingText,
                  fontSize: 11, height: 1.5)),
              const SizedBox(height: 11),
              OutlinedButton(
                onPressed: () => Navigator.of(sheet).pop(),
                child: const Text('إغلاق المعاينة')),
            ],
          )),
        ),
      ),
    );
  }

  Widget _intakeControls(AppThemeColors c) => AppSurface(
    child: Material(
      color: c.card,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('استقبال الحجوزات', style: TextStyle(
          color: c.petrol, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('التحكم في استقبال طلبات العملاء المعتمدين فقط',
          style: TextStyle(color: c.muted, fontSize: 11)),
        SwitchListTile.adaptive(
          key: const Key('bookings_accept_toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('فتح باب الحجوزات'),
          subtitle: Text(_settings.enabled ? 'مفتوح حسب ساعات الاستقبال' :
              'مغلق أمام جميع الطلبات'),
          value: _settings.enabled,
          onChanged: (value) => _setSettings(
            _settings.copyWith(enabled: value)),
        ),
        SwitchListTile.adaptive(
          key: const Key('bookings_all_day_toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('استقبال على مدار 24 ساعة'),
          value: _settings.allDay,
          onChanged: (value) =>
              _setSettings(_settings.copyWith(allDay: value)),
        ),
        if (!_settings.allDay)
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              key: const Key('bookings_start_time'),
              onPressed: () => _pickIntakeTime(true),
              icon: const Icon(Icons.access_time),
              label: Text('من ${_clock(_settings.opensAtMinute)}'),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              key: const Key('bookings_end_time'),
              onPressed: () => _pickIntakeTime(false),
              icon: const Icon(Icons.access_time_filled),
              label: Text('إلى ${_clock(_settings.closesAtMinute)}'),
            )),
          ]),
        const SizedBox(height: 7),
        Text(
          _settings.enabled
            ? (BookingIntakePolicy.isWindowOpen(_settings, DateTime.now())
              ? 'الاستقبال متاح الآن (بحسب توقيت صنعاء)'
              : 'الاستقبال خارج الوقت المحدد الآن')
            : 'لا يمكن تسجيل أي حجز جديد حتى فتح الباب.',
          style: TextStyle(
            color: _settings.enabled ? c.petrol : c.danger, fontSize: 11),
        ),
        Text('تسمح النافذة أيضاً بالفترات العابرة لمنتصف الليل. '
            'لا يوجد نشر لهذه الإعدادات إلى الخادم بعد.',
          style: TextStyle(color: c.muted, fontSize: 10)),
      ],
    ),
  ));
  Widget _reminderControls(AppThemeColors c) {
    final recipients = _audiencePreview();
    ReminderEngagementSummary? stats;
    if (widget.verifiedReminderEvents != null &&
        widget.verifiedReminderCampaignId != null) {
      stats = ReminderEngagementQuery.summarize(
        campaignId: widget.verifiedReminderCampaignId!,
        merchantId: widget.merchantId ?? '',
        recipientIds: widget.verifiedReminderRecipientIds,
        serverEvents: widget.verifiedReminderEvents!,
      );
    }
    return AppSurface(child: Material(
      color: c.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تذكير ليلي بحجوزات الغد', style: TextStyle(
            color: c.petrol, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('اختر الفئة، ثم ارفع فرصة تأكيد الحجز بضغطة واحدة.',
            style: TextStyle(color: c.muted, fontSize: 11)),
          SwitchListTile.adaptive(
            key: const Key('bookings_reminder_toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('تفعيل التذكير الليلي'),
            value: _reminder.enabled,
            onChanged: (value) => _setReminder(
              _reminder.copyWith(enabled: value)),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<NightReminderAudience>(
            key: const Key('reminder_audience'),
            value: _audience,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'إرسال التذكير إلى',
              prefixIcon: Icon(Icons.groups_2_outlined),
            ),
            items: [
              for (final audience in NightReminderAudience.values)
                DropdownMenuItem(
                  value: audience,
                  child: Text(audience.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                ),
            ],
            onChanged: (selected) {
              if (selected != null) setState(() => _audience = selected);
            },
          ),
          const SizedBox(height: 9),
          Text('المستهدفون المسموح لهم: ${recipients.length}',
            key: const Key('reminder_audience_count'),
            style: TextStyle(color: c.petrol, fontWeight: FontWeight.w800,
              fontSize: 12)),
          Text('العلاقات المعتمدة + موافقة الإشعارات + الفئة المختارة.',
            style: TextStyle(color: c.muted, fontSize: 10)),
          const SizedBox(height: 12),
          Text('تأكيد الحجز مباشرة من التذكير',
            style: TextStyle(color: c.text, fontWeight: FontWeight.w800,
              fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('reminder_offered_item'),
            controller: _offeredItem,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'الصنف المطلوب للحجز (إلزامي)',
              hintText: 'مثال: قات حاشدي',
            ),
          ),
          Text('التذكير دعوة حجز مباشرة، وليس إشعاراً عاماً. '
            'لن تُعتمد المعاينة بدون صنف محدد.',
            style: TextStyle(color: c.muted, fontSize: 10)),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              key: const Key('reminder_pickup_time'),
              onPressed: _pickCampaignPickupTime,
              icon: const Icon(Icons.schedule_rounded, size: 17),
              label: Text('وقت الاستلام: $_pickupTime',
                style: const TextStyle(fontSize: 11)),
            )),
            const SizedBox(width: 7),
            Expanded(child: OutlinedButton.icon(
              key: const Key('bookings_reminder_time'),
              onPressed: _pickReminderTime,
              icon: const Icon(Icons.nights_stay_outlined, size: 17),
              label: Text('التذكير: ${_clock(_reminder.sendAtMinute)}',
                style: const TextStyle(fontSize: 11)),
            )),
          ]),
          const SizedBox(height: 11),
          SizedBox(width: double.infinity,
            child: FilledButton.icon(
              key: const Key('bookings_reminder_preview'),
              onPressed: _offeredItem.text.trim().isEmpty
                  ? null : _previewReminder,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('معاينة دعوة الحجز'),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: c.cardBorder),
          const SizedBox(height: 7),
          Text('تفاعل العملاء مع التذكير', style: TextStyle(
            color: c.text, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Row(children: [
            _campaignMetric(c, 'وصل', stats?.deliveredCount),
            const SizedBox(width: 6),
            _campaignMetric(c, 'فتح', stats?.openedCount),
            const SizedBox(width: 6),
            _campaignMetric(c, 'أكد الحجز', stats?.confirmedCount),
          ]),
          const SizedBox(height: 5),
          Text(
            stats == null
                ? 'لا تتوفر إحصاءات فعلية قبل اتصال خدمة الإشعارات.'
                : 'نسبة الفتح من الرسائل الواصلة: '
                  '${stats.openedPercent?.toStringAsFixed(1) ?? '—'}%',
            style: TextStyle(color: c.muted, fontSize: 10),
          ),
          const SizedBox(height: 9),
          Text('مزايا التذكير والفئات والتحليلات والتأكيد السريع '
            'قابلة للتحكم في الباقات لاحقاً؛ لم تُحدد باقة أو تكلفة الآن.',
            style: TextStyle(color: c.muted, fontSize: 10)),
        ],
      ),
    ));
  }

  Widget _campaignMetric(
      AppThemeColors c, String title, int? count) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: c.background,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(count?.toString() ?? '—', style: TextStyle(
          color: c.petrol, fontWeight: FontWeight.w900, fontSize: 19)),
        const SizedBox(height: 3),
        Text(title, style: TextStyle(color: c.muted, fontSize: 10)),
      ]),
    ),
  );

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
    final amount = order.proposedDebtAmount;
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
                  ' • ${order.settlement == BookingSettlement.paid ? 'مسدد خارج التطبيق' : order.settlement == BookingSettlement.unpaid ? 'غير مسدد' : 'التسوية غير محددة'}',
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
    final debts = DailyDebtQuery.calculate(
      merchantId: widget.merchantId,
      day: day,
      movements: widget.state.movements.value,
      relationships: widget.state.relationships.value,
    );
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
              Text('التجهيز وديون اليوم في كشف واحد',
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
            _metric(c, '${debts.approvedCount}', 'ديون معتمدة'),
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
        _intakeControls(c),
        const SizedBox(height: 12),
        _reminderControls(c),
        const SizedBox(height: 12),
        AppSurface(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ديون اليوم', style: TextStyle(
              color: c.petrol, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('الديون التي وافق العميل على تسجيلها في هذا اليوم فقط؛ '
                'الحجوزات ليست ديوناً قبل الاعتماد.',
              style: TextStyle(color: c.muted, fontSize: 11)),
            const SizedBox(height: 9),
            for (final currency in CurrencyCode.values) ...[
              Row(children: [
                Text(FinanceDisplay.currencyCode(currency),
                  style: TextStyle(color: c.text,
                      fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(FinanceDisplay.amount(
                  debts.approved[currency] ?? Decimal.zero),
                  style: TextStyle(color: c.petrol, fontSize: 15,
                    fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 3),
              Text('طلبات معلقة: ${FinanceDisplay.amount(
                debts.pending[currency] ?? Decimal.zero)}',
                style: TextStyle(color: c.pendingText, fontSize: 10)),
              Divider(color: c.cardBorder, height: 13),
            ],
            Text('المبالغ المعلقة والمرفوضة لا تُضاف إلى المديونية '
                 'المعتمدة، ولا تُجمع العملات المختلفة.',
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
            ]),
            Wrap(spacing: 5, runSpacing: 0, children: [
              TextButton.icon(
                key: const Key('bookings_select_all'),
                onPressed: summary.orders.isEmpty ? null : () => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(summary.orders.map((order) => order.id));
                }),
                icon: const Icon(Icons.select_all_rounded, size: 17),
                label: const Text('تحديد الكل'),
              ),
              TextButton(
                key: const Key('bookings_select_all_eligible'),
                onPressed: qualified.isEmpty ? null : () => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(qualified);
                }),
                child: const Text('تحديد المؤهل'),
              ),
              TextButton(
                key: const Key('bookings_clear_selection'),
                onPressed: _selectedIds.isEmpty ? null
                    : () => setState(() => _selectedIds.clear()),
                child: const Text('إلغاء التحديد'),
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
                label: Text('مراجعة طلب تحويل ${_selectedIds.length} حجز إلى ديون'),
              ),
            ),
            const SizedBox(height: 8),
            Text('اختيار الكل أو حجوزات أشخاص محددين لا ينشئ ديناً. '
                'يصدر التاجر طلب الدين فقط بعد فحص الأهلية، '
                'ولا يعتمد إلا بعد موافقة كل عميل.',
              style: TextStyle(color: c.muted, fontSize: 10)),
          ],
        )),
      ],
    );
  }
}
