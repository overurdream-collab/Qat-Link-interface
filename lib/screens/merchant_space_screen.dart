import 'dart:typed_data';

import 'package:decimal/decimal.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_state.dart';
import '../models/app_models.dart';
import 'merchant_bookings_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/merchant_space/merchant_space_models.dart';
import '../widgets/merchant_space/merchant_rating_policy.dart';
import '../widgets/quick_actions/approved_customer_picker_model.dart';
import '../widgets/merchant_space/reservation_daily_pdf.dart';

class MerchantSpaceTab extends StatefulWidget {
  const MerchantSpaceTab({super.key, required this.state, this.merchantId});

  final AppState state;
  final String? merchantId;

  @override
  State<MerchantSpaceTab> createState() => _MerchantSpaceTabState();
}

class _StudioDraft {
  const _StudioDraft(this.title, this.isVideo, this.image, this.createdAt);
  final String title;
  final bool isVideo;
  final Uint8List? image;
  final DateTime createdAt;
}

class _MerchantSpaceTabState extends State<MerchantSpaceTab> {
  final _notifications = TextEditingController();
  final _picker = ImagePicker();
  final _draftBookings = <ReservationDraft>[];
  final _studioDrafts = <_StudioDraft>[];
  DateTime _day = DateTime.now();
  bool _isOpen = false;
  bool _exporting = false;
  bool _bookingsOpen = false;
  String _storeName = 'متجرك';
  String? _governorate;
  String _marketName = '';
  String _locationUrl = '';
  Uint8List? _banner;
  BroadcastAudience _audience = BroadcastAudience.all;
  String _noticeKind = 'عروض جديدة';

  static const _governorates = <String>[
    'أمانة العاصمة', 'صنعاء', 'عدن', 'تعز', 'إب', 'ذمار',
    'الحديدة', 'حجة', 'عمران', 'صعدة', 'الجوف', 'مأرب',
    'البيضاء', 'الضالع', 'لحج', 'أبين', 'شبوة', 'حضرموت',
    'المهرة', 'سقطرى', 'ريمة', 'المحويت',
  ];
  static const _templates = <String, String>{
    'عروض جديدة': 'وصلت عروض جديدة في متجرنا. تابعوا الجديد.',
    'وصول بضاعة': 'وصلت بضاعة جديدة إلى المتجر. نتشرف بزيارتكم.',
    'انخفاض الأسعار': 'انخفضت أسعار أصناف مختارة. تابعوا تحديثات المتجر.',
    'تذكير بالسداد': 'يرجى مراجعة المبالغ المستحقة في حسابكم.',
    'مراجعة المعلقات': 'لديكم عمليات تحتاج المراجعة والموافقة أو الرفض.',
    'تنبيه مخصص': '',
  };

  @override
  void dispose() {
    _notifications.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _chooseBanner() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _banner = bytes);
      _message('تم اختيار بانر للمعاينة المحلية فقط. لم يتم نشره.');
    } catch (_) {
      if (mounted) _message('تعذر اختيار صورة البانر.');
    }
  }

  Future<void> _chooseMedia(bool video) async {
    try {
      final picked = video
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(
              source: ImageSource.gallery, maxWidth: 1100,
              imageQuality: 80,
            );
      if (picked == null) return;
      final bytes = video ? null : await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _studioDrafts.insert(0, _StudioDraft(
          picked.name, video, bytes, DateTime.now()));
      });
      _message('أضيف الملف إلى مسودات الاستوديو على هذه الشاشة فقط؛ '
          'لم يُنشر ولم يُرسل لأي عميل.');
    } catch (_) {
      if (mounted) _message('تعذر الوصول للوسائط. تحقق من أذونات المعرض.');
    }
  }

  Future<void> _editProfile() async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: _storeName == 'متجرك' ? '' : _storeName);
    final market = TextEditingController(text: _marketName);
    final location = TextEditingController(text: _locationUrl);
    var governorate = _governorate;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.card,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, refresh) {
          final c = sheet.colors;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18, 9, 18, MediaQuery.viewInsetsOf(sheet).bottom + 20),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('إعدادات واجهة المتجر', style: TextStyle(
                        color: c.petrol, fontWeight: FontWeight.w900,
                        fontSize: 18,
                      )),
                      const SizedBox(height: 5),
                      Text('تُحفظ التغييرات هنا كمعاينة فقط حتى ربط خادم المتجر.',
                          style: TextStyle(color: c.muted, fontSize: 11)),
                      const SizedBox(height: 17),
                      TextFormField(
                        key: const Key('store_profile_name'),
                        controller: name, maxLength: 70,
                        decoration: const InputDecoration(
                          labelText: 'اسم المتجر',
                          prefixIcon: Icon(Icons.storefront_outlined)),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'أدخل اسم المتجر' : null,
                      ),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        key: const Key('store_profile_governorate'),
                        value: governorate,
                        isExpanded: true,
                        hint: const Text('اختر المحافظة'),
                        decoration: const InputDecoration(
                          labelText: 'المحافظة',
                          prefixIcon: Icon(Icons.place_outlined)),
                        items: [
                          for (final item in _governorates)
                            DropdownMenuItem(value: item, child: Text(item)),
                        ],
                        onChanged: (v) => refresh(() => governorate = v),
                        validator: (v) => v == null
                            ? 'المحافظة مطلوبة' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('store_profile_market'),
                        controller: market, maxLength: 90,
                        decoration: const InputDecoration(
                          labelText: 'اسم السوق / الشارع',
                          prefixIcon: Icon(Icons.store_mall_directory_outlined)),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'أدخل اسم السوق' : null,
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        key: const Key('store_profile_location'),
                        controller: location,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'رابط الموقع من الخرائط (اختياري)',
                          hintText: 'https://maps.app.goo.gl/...',
                          prefixIcon: Icon(Icons.map_outlined)),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) return null;
                          final uri = Uri.tryParse(v!.trim());
                          return uri != null &&
                                  uri.scheme == 'https' &&
                                  (uri.host == 'maps.app.goo.gl' ||
                                   uri.host == 'maps.google.com' ||
                                   uri.host == 'www.google.com' ||
                                   uri.host == 'www.openstreetmap.org')
                              ? null : 'أدخل رابط خرائط HTTPS معروفاً';
                        },
                      ),
                      const SizedBox(height: 13),
                      FilledButton.icon(
                        key: const Key('save_store_profile'),
                        onPressed: () {
                          if (form.currentState?.validate() != true) return;
                          Navigator.of(sheet).pop(true);
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('حفظ المعاينة'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (updated == true) {
      setState(() {
        _storeName = name.text.trim();
        _governorate = governorate;
        _marketName = market.text.trim();
        _locationUrl = location.text.trim();
      });
      _message('تم تعديل بيانات المعاينة المحلية؛ لم تُنشر على المتجر العام.');
    }
    // The modal route remains mounted during its reverse animation.
    // Keep input controllers alive until the sheet is fully removed.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    name.dispose();
    market.dispose();
    location.dispose();
  }

  Future<void> _pickDay() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2025),
      lastDate: DateTime(2100),
      helpText: 'تاريخ كشف الحجوزات',
    );
    if (mounted && day != null) setState(() => _day = day);
  }

  Future<void> _addBooking() async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final item = TextEditingController();
    final bundles = TextEditingController(text: '1');
    final time = TextEditingController(text: '11:00');
    final note = TextEditingController();
    final unitPrice = TextEditingController();
    String? linkedCustomerId;
    var bookingCurrency = CurrencyCode.yer;
    var settlement = BookingSettlement.unknown;
    final eligibleCustomers = ApprovedCustomerPickerModel.available(
      customers: widget.state.customers.value,
      relationships: widget.state.relationships.value,
      merchantId: widget.merchantId,
    );
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, refresh) {
        final c = sheet.colors;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18, 8, 18, MediaQuery.viewInsetsOf(sheet).bottom + 20),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('إضافة حجز سريع', style: TextStyle(
                      fontSize: 19, color: c.petrol,
                      fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('طلب تجهيز محلي ليوم ${_formatDay(_day)} — '
                        'لا ينشئ عملية مالية أو موافقة من العميل.',
                        style: TextStyle(color: c.muted, fontSize: 11)),
                    const SizedBox(height: 13),
                    TextFormField(
                      key: const Key('booking_customer'),
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'اسم صاحب الحجز',
                        prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => (v ?? '').trim().length < 2
                          ? 'أدخل اسم صاحب الحجز' : null,
                    ),
                    if (eligibleCustomers.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      DropdownButtonFormField<String>(
                        key: const Key('booking_linked_customer'),
                        value: linkedCustomerId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'العميل المرتبط (اختياري للتحويل إلى دين)',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                        items: [
                          for (final option in eligibleCustomers)
                            DropdownMenuItem(
                              value: option.customer.id,
                              child: Text(option.customer.name,
                                overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (value) {
                          refresh(() => linkedCustomerId = value);
                          if (value != null) {
                            final chosen = eligibleCustomers.firstWhere(
                              (x) => x.customer.id == value,
                            ).customer;
                            name.text = chosen.name;
                            phone.text = chosen.phone;
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 11),
                    TextFormField(
                      key: const Key('booking_phone'),
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الجوال (اختياري)',
                        prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      key: const Key('booking_item'),
                      controller: item,
                      decoration: const InputDecoration(
                        labelText: 'الصنف / نوع القات',
                        prefixIcon: Icon(Icons.eco_outlined)),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'أدخل الصنف' : null,
                    ),
                    const SizedBox(height: 11),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('booking_bundles'),
                          controller: bundles,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'عدد الربطات'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n <= 0 || n > 10000
                                ? 'أدخل عدداً بين 1 و10000' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          key: const Key('booking_pickup'),
                          controller: time,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'وقت الاستلام',
                            hintText: '11:00',
                          ),
                          validator: (v) => RegExp(
                            r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$',
                          ).hasMatch(v ?? '') ? null : 'مثال: 11:00',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: const Key('booking_unit_price'),
                          controller: unitPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'سعر الربطة (اختياري)',
                          ),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) return null;
                            final amount = Decimal.tryParse(v!.trim());
                            if (amount == null || amount <= Decimal.zero ||
                                !RegExp(r'^\\d+(?:\\.\\d{1,2})?
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات التجهيز (اختياري)',
                        prefixIcon: Icon(Icons.sticky_note_2_outlined)),
                    ),
                    FilledButton.icon(
                      key: const Key('booking_save_draft'),
                      onPressed: () {
                        if (form.currentState?.validate() == true) {
                          Navigator.of(sheet).pop(true);
                        }
                      },
                      icon: const Icon(Icons.playlist_add_check_rounded),
                      label: const Text('إضافة إلى كشف التجهيز المحلي'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
    if (!mounted) return;
    if (added == true) {
      setState(() {
        _draftBookings.add(ReservationDraft(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          customerName: name.text.trim(),
          phone: phone.text.trim(),
          item: item.text.trim(),
          bundles: int.parse(bundles.text),
          day: DateTime(_day.year, _day.month, _day.day),
          pickupTime: time.text.trim(),
          createdAt: DateTime.now(),
          note: note.text.trim(),
          customerId: linkedCustomerId,
          unitPrice: unitPrice.text.trim().isEmpty
              ? null : Decimal.parse(unitPrice.text.trim()),
          currency: bookingCurrency,
          settlement: settlement,
        ));
      });
      _message('أضيف الحجز إلى قائمة هذا الجهاز مؤقتاً. '
          'لم يُرسل إلى العميل أو الخادم.');
    }
    // A popped bottom sheet still animates out; disposing immediately
    // breaks TextFormField listeners during that transition.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    name.dispose(); phone.dispose(); item.dispose();
    bundles.dispose(); time.dispose(); note.dispose(); unitPrice.dispose();
  }

  Future<void> _exportBookings(ReservationDailySummary summary) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pdf = await ReservationDailyPdf.generate(
        day: _day, storeName: _storeName,
        governorate: _governorate, marketName: _marketName,
        summary: summary,
      );
      await ReservationDailyPdf.printFile(pdf, day: _day);
    } catch (_) {
      if (mounted) _message('تعذر إعداد كشف التجهيز PDF.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _previewNotification(int recipients) {
    final msg = _notifications.text.trim();
    if (msg.isEmpty) {
      _message('اكتب رسالة التنبيه أولاً.');
      return;
    }
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('مراجعة التنبيه', style: TextStyle(
                color: c.petrol, fontSize: 18,
                fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('الفئة: ${_audience.label} • $recipients عميل',
                style: TextStyle(color: c.muted)),
              const SizedBox(height: 7),
              Text(msg, style: TextStyle(color: c.text, height: 1.6)),
              const SizedBox(height: 12),
              Text('لا يوجد إرسال فعلي في هذه النسخة. يتطلب تفعيل '
                   'الخادم، أذونات العملاء، وحدود الإرسال.',
                style: TextStyle(color: c.pendingText, fontSize: 11)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(sheet).pop(),
                child: const Text('إغلاق المراجعة')),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDay(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2,'0')}/'
      '${value.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final summary = ReservationsQuery.forDay(_draftBookings, _day);
    if (_bookingsOpen) {
      return MerchantBookingsScreen(
        bookings: _draftBookings,
        day: _day,
        onDayChanged: (day) => setState(() => _day = day),
        onAddBooking: _addBooking,
        onUpdateBooking: (id, status) => setState(() {
          final at = _draftBookings.indexWhere((b) => b.id == id);
          if (at >= 0) _draftBookings[at] = _draftBookings[at].withStatus(status);
        }),
        onBack: () => setState(() => _bookingsOpen = false),
        state: widget.state,
        merchantId: widget.merchantId,
        storeName: _storeName,
      );
    }
    return ListView(
      key: const Key('merchant_space_scroll'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مساحتي', style: TextStyle(
                color: c.text, fontSize: 22, fontWeight: FontWeight.w900)),
              Text('مركز إدارة المتجر • تجهيز، تسويق، حجوزات',
                style: TextStyle(color: c.muted, fontSize: 11)),
            ],
          )),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.pale, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.storefront_rounded, color: c.petrol),
          ),
        ]),
        const SizedBox(height: 13),
        _hero(c),
        const SizedBox(height: 12),
        _location(c),
        const SizedBox(height: 14),
        _dailyBookings(c, summary),
        const SizedBox(height: 15),
        _studio(c),
        const SizedBox(height: 15),
        AnimatedBuilder(
          animation: Listenable.merge([
            widget.state.customers,
            widget.state.relationships,
            widget.state.movements,
          ]),
          builder: (context, _) => _broadcast(c),
        ),
        const SizedBox(height: 15),
        _engagement(c),
        const SizedBox(height: 13),
        _ratings(c),
        const SizedBox(height: 13),
        Text('كل التعديلات والحجوزات هنا مسودات محلية للتجربة؛ '
             'لا تُنشر ولا تصل للعملاء قبل ربط الخادم.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 10, height: 1.6)),
      ],
    );
  }

  Widget _hero(AppThemeColors c) => Container(
    height: 178,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: AppGradients.hero,
      borderRadius: BorderRadius.circular(23),
      boxShadow: AppColors.cardShadow,
    ),
    child: Stack(children: [
      if (_banner != null)
        Positioned.fill(child: Image.memory(_banner!, fit: BoxFit.cover)),
      if (_banner != null)
        Positioned.fill(child: Container(color: Colors.black.withValues(alpha: .35))),
      Positioned(
        left: -50, top: -55,
        child: Icon(Icons.eco_rounded, size: 220,
          color: Colors.white.withValues(alpha: .12)),
      ),
      Positioned.fill(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .17),
                  border: Border.all(color: Colors.white.withValues(alpha: .27)),
                  borderRadius: BorderRadius.circular(20)),
                child: const Text('متجر التاجر',
                  style: TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  key: const Key('store_open_toggle'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() => _isOpen = !_isOpen);
                    _message('تغيرت حالة المتجر في المعاينة فقط؛ '
                      'لم تُنشر للعملاء.');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 10,
                        color: _isOpen ? const Color(0xFF16A34A)
                          : const Color(0xFFC04444)),
                      const SizedBox(width: 5),
                      Text(_isOpen ? 'مفتوح' : 'مغلق',
                        style: TextStyle(
                          color: _isOpen ? const Color(0xFF16845B)
                            : const Color(0xFFC04444),
                          fontSize: 12, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
              ),
            ]),
            const Spacer(),
            Text(_storeName, maxLines: 1,
                overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w900, fontSize: 23)),
            const SizedBox(height: 3),
            Text('واجهة متجرك وعروضك اليومية',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .93),
                fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: [
              _heroAction(Icons.edit_outlined, 'بيانات المتجر', _editProfile),
              const SizedBox(width: 8),
              _heroAction(Icons.photo_camera_outlined, 'تغيير البانر', _chooseBanner),
            ]),
          ],
        ),
      )),
    ]),
  );

  Widget _heroAction(
    IconData icon, String text, VoidCallback callback) => Material(
    color: Colors.white.withValues(alpha: .2),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: callback, borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(
            color: Colors.white, fontSize: 10,
            fontWeight: FontWeight.w800)),
        ]),
      ),
    ),
  );

  Widget _location(AppThemeColors c) => AppSurface(
    padding: const EdgeInsets.all(13),
    child: Row(children: [
      Container(
        height: 42, width: 42,
        decoration: BoxDecoration(
          color: c.pale, borderRadius: BorderRadius.circular(13)),
        child: Icon(Icons.location_on_outlined, color: c.petrol)),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('عنوان المتجر', style: TextStyle(
            color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(_governorate == null ? 'المحافظة والسوق غير محددين'
                  : '${_governorate!} • $_marketName',
              style: TextStyle(color: c.muted, fontSize: 11)),
          if (_locationUrl.isNotEmpty)
            Text('تم إضافة رابط الموقع',
              style: TextStyle(color: c.success, fontSize: 10)),
        ],
      )),
      TextButton.icon(
        key: const Key('edit_store_location'),
        onPressed: _editProfile,
        icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
        label: const Text('تحديد'),
      ),
    ]),
  );

  Widget _section(AppThemeColors c, IconData icon, String title,
      String subtitle, {Widget? action}) => Row(children: [
    Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: c.pale, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: c.petrol, size: 21),
    ),
    const SizedBox(width: 9),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
          color: c.text, fontSize: 15, fontWeight: FontWeight.w900)),
        Text(subtitle, style: TextStyle(color: c.muted, fontSize: 10)),
      ],
    )),
    if (action != null) action,
  ]);

  Widget _dailyBookings(
      AppThemeColors c, ReservationDailySummary summary) => AppSurface(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(c, Icons.event_note_outlined, 'حجوزات اليوم',
          'كشف واحد لتجهيز الطلبات بدلاً من الاتصالات',
          action: TextButton(
            key: const Key('open_bookings_screen'),
            onPressed: () => setState(() => _bookingsOpen = true),
            child: const Text('إدارة الكل'),
          )),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            key: const Key('booking_date'),
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_today_rounded, size: 15),
            label: Text(_formatDay(_day), style: const TextStyle(fontSize: 11)),
          )),
          const SizedBox(width: 9),
          Expanded(child: FilledButton.icon(
            key: const Key('booking_add_quick'),
            onPressed: _addBooking,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('حجز سريع', style: TextStyle(fontSize: 12)),
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _miniMetric(c, 'الحجوزات النشطة', '${summary.activeCount}',
              Icons.receipt_long_rounded),
          const SizedBox(width: 7),
          _miniMetric(c, 'الربطات المطلوبة', '${summary.totalBundles}',
              Icons.eco_outlined),
          const SizedBox(width: 7),
          _miniMetric(c, 'جاهز للاستلام', '${summary.readyCount}',
              Icons.task_alt_rounded),
        ]),
        const SizedBox(height: 12),
        if (summary.orders.isEmpty)
          _empty(c, Icons.calendar_month_outlined,
              'لا توجد حجوزات لهذا اليوم',
              'أضف أول حجز وسيظهر في كشف التجهيز.')
        else
          for (final order in summary.orders) ...[
            _bookingRow(c, order),
            const SizedBox(height: 7),
          ],
        if (summary.bundlesByItem.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final group in summary.bundlesByItem.entries)
              Chip(
                label: Text('${group.key}: ${group.value} ربطة',
                    style: const TextStyle(fontSize: 10)),
                backgroundColor: c.pale,
                side: BorderSide(color: c.cardBorder),
              ),
          ]),
        ],
        const SizedBox(height: 7),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('booking_export_pdf'),
            onPressed: _exporting ? null : () => _exportBookings(summary),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_exporting
                ? 'جارٍ إعداد الكشف' : 'استخراج كشف التجهيز اليومي PDF',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        Text('مسودة الجهاز فقط • لا توجد حجوزات متزامنة من العملاء بعد.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: c.muted)),
      ],
    ),
  );

  Widget _miniMetric(
    AppThemeColors c, String title, String value, IconData icon) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: c.background,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.petrol, size: 16),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(
            fontWeight: FontWeight.w900, color: c.text, fontSize: 20)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: TextStyle(
              color: c.muted, fontSize: 10)),
          ),
        ],
      ),
    ));

  Widget _bookingRow(AppThemeColors c, ReservationDraft order) {
    final active = order.status != ReservationStatus.cancelled &&
        order.status != ReservationStatus.collected;
    return Container(
      key: Key('booking_row_${order.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: c.background,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(
          radius: 18, backgroundColor: c.pale,
          child: Icon(Icons.shopping_bag_outlined,
              color: c.petrol, size: 19)),
        const SizedBox(width: 7),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.customerName, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.text, fontSize: 12,
                  fontWeight: FontWeight.w900)),
            Text('${order.item} • ${order.bundles} ربطة • ${order.pickupTime}',
              style: TextStyle(color: c.muted, fontSize: 10)),
            Text(order.status.label, style: TextStyle(
              color: active ? c.pendingText : c.success,
              fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        )),
        PopupMenuButton<ReservationStatus>(
          tooltip: 'حالة الحجز المحلي',
          onSelected: (status) => setState(() {
            final index = _draftBookings.indexWhere((b) => b.id == order.id);
            if (index >= 0) {
              _draftBookings[index] = order.withStatus(status);
            }
          }),
          itemBuilder: (_) => [
            for (final status in ReservationStatus.values)
              PopupMenuItem(value: status, child: Text(
                status.label, style: const TextStyle(fontSize: 12))),
          ],
          icon: Icon(Icons.more_vert_rounded, color: c.petrol),
        ),
      ]),
    );
  }

  Widget _empty(AppThemeColors c, IconData icon, String title,
      String subtitle) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 19, horizontal: 10),
    decoration: BoxDecoration(
      color: c.background,
      border: Border.all(color: c.cardBorder),
      borderRadius: BorderRadius.circular(13)),
    child: Column(children: [
      Icon(icon, color: c.muted, size: 27),
      const SizedBox(height: 7),
      Text(title, style: TextStyle(
        color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(subtitle, textAlign: TextAlign.center,
        style: TextStyle(color: c.muted, fontSize: 10)),
    ]),
  );

  Widget _studio(AppThemeColors c) => AppSurface(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(c, Icons.movie_creation_outlined, 'استوديو التاجر',
          'صور يومية وفيديوهات للترويج للبضاعة'),
        const SizedBox(height: 13),
        Row(children: [
          _studioTile(c, Icons.add_photo_alternate_outlined,
              'إضافة صور', AppColors.success, () => _chooseMedia(false)),
          const SizedBox(width: 9),
          _studioTile(c, Icons.video_call_outlined,
              'إضافة فيديو', AppColors.sea, () => _chooseMedia(true)),
        ]),
        const SizedBox(height: 10),
        if (_studioDrafts.isEmpty)
          Text('لم تُضف وسائط بعد. تظهر منشوراتك المحفوظة بعد ربط الاستوديو.',
            style: TextStyle(color: c.muted, fontSize: 11))
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _studioDrafts.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _studioDrafts[index];
                return Container(
                  width: 110, padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: c.background,
                    border: Border.all(color: c.cardBorder),
                    borderRadius: BorderRadius.circular(11)),
                  child: Column(children: [
                    SizedBox(
                      height: 51, width: double.infinity,
                      child: item.image != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.memory(item.image!,
                                fit: BoxFit.cover))
                          : Icon(Icons.play_circle_outline_rounded,
                            color: c.petrol, size: 36),
                    ),
                    const SizedBox(height: 4),
                    Text(item.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.text, fontSize: 9)),
                    Text('مسودة',
                      style: TextStyle(color: c.pendingText, fontSize: 9)),
                  ]),
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.send_outlined, color: c.petrol, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(
            'مشاركة الصور والفيديوهات مع العملاء بعد النشر '
            'وتفعيل الموافقات على التنبيهات.',
            style: TextStyle(color: c.muted, fontSize: 10))),
        ]),
      ],
    ),
  );

  Widget _studioTile(AppThemeColors c, IconData icon, String label,
      Color color, VoidCallback action) => Expanded(child: Material(
    color: color.withValues(alpha: .09),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: Key(label == 'إضافة صور' ? 'studio_add_photo' : 'studio_add_video'),
      onTap: action,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 87,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: .24)),
          borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 27),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ),
  ));

  Widget _broadcast(AppThemeColors c) {
    final people = MerchantAudienceQuery.eligible(
      merchantId: widget.merchantId,
      customers: widget.state.customers.value,
      relationships: widget.state.relationships.value,
      movements: widget.state.movements.value,
      audience: _audience,
    );
    return AppSurface(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(c, Icons.campaign_outlined, 'تنبيهات العملاء',
            'رسائل دقيقة حسب الفئة، دون إزعاج'),
          const SizedBox(height: 12),
          SizedBox(height: 36, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: BroadcastAudience.values.length,
            separatorBuilder: (_, index) => const SizedBox(width: 7),
            itemBuilder: (context, i) {
              final kind = BroadcastAudience.values[i];
              final selected = _audience == kind;
              return ChoiceChip(
                key: Key('broadcast_${kind.name}'),
                showCheckmark: false,
                selected: selected,
                selectedColor: c.pale,
                backgroundColor: c.card,
                side: BorderSide(
                  color: selected ? c.petrol : c.cardBorder),
                label: Text(kind.label, style: TextStyle(
                  color: selected ? c.petrol : c.text,
                  fontSize: 11, fontWeight: FontWeight.w700)),
                onSelected: (_) => setState(() => _audience = kind),
              );
            },
          )),
          const SizedBox(height: 10),
          Row(children: [
            Text('المستهدفون: ${people.length}', style: TextStyle(
              color: c.petrol, fontSize: 12,
              fontWeight: FontWeight.w900)),
            const Spacer(),
            Text('العلاقات المعتمدة فقط',
              style: TextStyle(color: c.muted, fontSize: 10)),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const Key('broadcast_template'),
            value: _noticeKind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع التنبيه'),
            items: [
              for (final kind in _templates.keys)
                DropdownMenuItem(value: kind,
                    child: Text(kind, style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _noticeKind = v;
                _notifications.text = _templates[v] ?? '';
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('broadcast_message'),
            controller: _notifications,
            minLines: 2, maxLines: 4,
            maxLength: 280,
            decoration: const InputDecoration(
              hintText: 'اكتب التنبيه الذي تريد إرساله لعملائك...',
            ),
          ),
          SizedBox(width: double.infinity,
            child: FilledButton.icon(
              key: const Key('broadcast_review'),
              onPressed: () => _previewNotification(people.length),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('مراجعة التنبيه قبل الإرسال'),
            ),
          ),
          Text('الإرسال الفعلي لم يُفعّل بعد؛ '
              'سيتطلب موافقة التلقي ومنع تكرار الرسائل.',
            style: TextStyle(color: c.muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _engagement(AppThemeColors c) => AppSurface(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(c, Icons.analytics_outlined, 'تفاعل الجمهور',
            'ما الذي يشاهده عملاؤك ويتفاعلون معه؟'),
        const SizedBox(height: 13),
        Row(children: [
          _engagementMetric(c, 'المشاهدات', Icons.visibility_outlined),
          const SizedBox(width: 7),
          _engagementMetric(c, 'الإعجابات', Icons.favorite_border_rounded),
          const SizedBox(width: 7),
          _engagementMetric(c, 'المشاركات', Icons.ios_share_outlined),
        ]),
        const SizedBox(height: 11),
        _empty(c, Icons.insights_rounded,
          'الأكثر مشاهدة ومشاركة',
          'لا توجد إحصاءات منشورة بعد. سيظهر ترتيب المحتوى '
          'عند توفر بيانات مشاهدة ومشاركة حقيقية.'),
      ],
    ),
  );

  Widget _engagementMetric(AppThemeColors c, String title,
      IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: c.background,
      border: Border.all(color: c.cardBorder),
      borderRadius: BorderRadius.circular(11)),
    child: Column(children: [
      Icon(icon, color: c.petrol, size: 19),
      const SizedBox(height: 6),
      Text('—', style: TextStyle(
        color: c.text, fontWeight: FontWeight.w900, fontSize: 20)),
      Text(title, style: TextStyle(color: c.muted, fontSize: 10)),
    ]),
  ));
}
)
                                    .hasMatch(v.trim())) {
                              return 'سعر موجب حتى منزلتين';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: DropdownButtonFormField<CurrencyCode>(
                          key: const Key('booking_currency'),
                          value: bookingCurrency,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'العملة'),
                          items: [
                            for (final curr in CurrencyCode.values)
                              DropdownMenuItem(
                                value: curr,
                                child: Text(curr.name.toUpperCase()),
                              ),
                          ],
                          onChanged: (value) => refresh(() {
                            if (value != null) bookingCurrency = value;
                          }),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BookingSettlement>(
                      key: const Key('booking_settlement'),
                      value: settlement,
                      decoration: const InputDecoration(labelText: 'حالة السداد'),
                      items: const [
                        DropdownMenuItem(
                          value: BookingSettlement.unknown,
                          child: Text('غير محدد بعد'),
                        ),
                        DropdownMenuItem(
                          value: BookingSettlement.paid,
                          child: Text('مسدد نقداً'),
                        ),
                        DropdownMenuItem(
                          value: BookingSettlement.unpaid,
                          child: Text('لم يسدد'),
                        ),
                      ],
                      onChanged: (value) => refresh(() {
                        if (value != null) settlement = value;
                      }),
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: note, maxLength: 250,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات التجهيز (اختياري)',
                        prefixIcon: Icon(Icons.sticky_note_2_outlined)),
                    ),
                    FilledButton.icon(
                      key: const Key('booking_save_draft'),
                      onPressed: () {
                        if (form.currentState?.validate() == true) {
                          Navigator.of(sheet).pop(true);
                        }
                      },
                      icon: const Icon(Icons.playlist_add_check_rounded),
                      label: const Text('إضافة إلى كشف التجهيز المحلي'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (added == true) {
      setState(() {
        _draftBookings.add(ReservationDraft(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          customerName: name.text.trim(),
          phone: phone.text.trim(),
          item: item.text.trim(),
          bundles: int.parse(bundles.text),
          day: DateTime(_day.year, _day.month, _day.day),
          pickupTime: time.text.trim(),
          createdAt: DateTime.now(),
          note: note.text.trim(),
        ));
      });
      _message('أضيف الحجز إلى قائمة هذا الجهاز مؤقتاً. '
          'لم يُرسل إلى العميل أو الخادم.');
    }
    // A popped bottom sheet still animates out; disposing immediately
    // breaks TextFormField listeners during that transition.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    name.dispose(); phone.dispose(); item.dispose();
    bundles.dispose(); time.dispose(); note.dispose();
  }

  Future<void> _exportBookings(ReservationDailySummary summary) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pdf = await ReservationDailyPdf.generate(
        day: _day, storeName: _storeName,
        governorate: _governorate, marketName: _marketName,
        summary: summary,
      );
      await ReservationDailyPdf.printFile(pdf, day: _day);
    } catch (_) {
      if (mounted) _message('تعذر إعداد كشف التجهيز PDF.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _previewNotification(int recipients) {
    final msg = _notifications.text.trim();
    if (msg.isEmpty) {
      _message('اكتب رسالة التنبيه أولاً.');
      return;
    }
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('مراجعة التنبيه', style: TextStyle(
                color: c.petrol, fontSize: 18,
                fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('الفئة: ${_audience.label} • $recipients عميل',
                style: TextStyle(color: c.muted)),
              const SizedBox(height: 7),
              Text(msg, style: TextStyle(color: c.text, height: 1.6)),
              const SizedBox(height: 12),
              Text('لا يوجد إرسال فعلي في هذه النسخة. يتطلب تفعيل '
                   'الخادم، أذونات العملاء، وحدود الإرسال.',
                style: TextStyle(color: c.pendingText, fontSize: 11)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(sheet).pop(),
                child: const Text('إغلاق المراجعة')),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDay(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2,'0')}/'
      '${value.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final summary = ReservationsQuery.forDay(_draftBookings, _day);
    return ListView(
      key: const Key('merchant_space_scroll'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مساحتي', style: TextStyle(
                color: c.text, fontSize: 22, fontWeight: FontWeight.w900)),
              Text('مركز إدارة المتجر • تجهيز، تسويق، حجوزات',
                style: TextStyle(color: c.muted, fontSize: 11)),
            ],
          )),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.pale, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.storefront_rounded, color: c.petrol),
          ),
        ]),
        const SizedBox(height: 13),
        _hero(c),
        const SizedBox(height: 12),
        _location(c),
        const SizedBox(height: 14),
        _dailyBookings(c, summary),
        const SizedBox(height: 15),
        _studio(c),
        const SizedBox(height: 15),
        AnimatedBuilder(
          animation: Listenable.merge([
            widget.state.customers,
            widget.state.relationships,
            widget.state.movements,
          ]),
          builder: (context, _) => _broadcast(c),
        ),
        const SizedBox(height: 15),
        _engagement(c),
        const SizedBox(height: 13),
        Text('كل التعديلات والحجوزات هنا مسودات محلية للتجربة؛ '
             'لا تُنشر ولا تصل للعملاء قبل ربط الخادم.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 10, height: 1.6)),
      ],
    );
  }

  Widget _hero(AppThemeColors c) => Container(
    height: 178,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: AppGradients.hero,
      borderRadius: BorderRadius.circular(23),
      boxShadow: AppColors.cardShadow,
    ),
    child: Stack(children: [
      if (_banner != null)
        Positioned.fill(child: Image.memory(_banner!, fit: BoxFit.cover)),
      if (_banner != null)
        Positioned.fill(child: Container(color: Colors.black.withValues(alpha: .35))),
      Positioned(
        left: -50, top: -55,
        child: Icon(Icons.eco_rounded, size: 220,
          color: Colors.white.withValues(alpha: .12)),
      ),
      Positioned.fill(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .17),
                  border: Border.all(color: Colors.white.withValues(alpha: .27)),
                  borderRadius: BorderRadius.circular(20)),
                child: const Text('متجر التاجر',
                  style: TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  key: const Key('store_open_toggle'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() => _isOpen = !_isOpen);
                    _message('تغيرت حالة المتجر في المعاينة فقط؛ '
                      'لم تُنشر للعملاء.');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 10,
                        color: _isOpen ? const Color(0xFF16A34A)
                          : const Color(0xFFC04444)),
                      const SizedBox(width: 5),
                      Text(_isOpen ? 'مفتوح' : 'مغلق',
                        style: TextStyle(
                          color: _isOpen ? const Color(0xFF16845B)
                            : const Color(0xFFC04444),
                          fontSize: 12, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
              ),
            ]),
            const Spacer(),
            Text(_storeName, maxLines: 1,
                overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w900, fontSize: 23)),
            const SizedBox(height: 3),
            Text('واجهة متجرك وعروضك اليومية',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .93),
                fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: [
              _heroAction(Icons.edit_outlined, 'بيانات المتجر', _editProfile),
              const SizedBox(width: 8),
              _heroAction(Icons.photo_camera_outlined, 'تغيير البانر', _chooseBanner),
            ]),
          ],
        ),
      )),
    ]),
  );

  Widget _heroAction(
    IconData icon, String text, VoidCallback callback) => Material(
    color: Colors.white.withValues(alpha: .2),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: callback, borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(
            color: Colors.white, fontSize: 10,
            fontWeight: FontWeight.w800)),
        ]),
      ),
    ),
  );

  Widget _location(AppThemeColors c) => AppSurface(
    padding: const EdgeInsets.all(13),
    child: Row(children: [
      Container(
        height: 42, width: 42,
        decoration: BoxDecoration(
          color: c.pale, borderRadius: BorderRadius.circular(13)),
        child: Icon(Icons.location_on_outlined, color: c.petrol)),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('عنوان المتجر', style: TextStyle(
            color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(_governorate == null ? 'المحافظة والسوق غير محددين'
                  : '${_governorate!} • $_marketName',
              style: TextStyle(color: c.muted, fontSize: 11)),
          if (_locationUrl.isNotEmpty)
            Text('تم إضافة رابط الموقع',
              style: TextStyle(color: c.success, fontSize: 10)),
        ],
      )),
      TextButton.icon(
        key: const Key('edit_store_location'),
        onPressed: _editProfile,
        icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
        label: const Text('تحديد'),
      ),
    ]),
  );

  Widget _section(AppThemeColors c, IconData icon, String title,
      String subtitle, {Widget? action}) => Row(children: [
    Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: c.pale, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: c.petrol, size: 21),
    ),
    const SizedBox(width: 9),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
          color: c.text, fontSize: 15, fontWeight: FontWeight.w900)),
        Text(subtitle, style: TextStyle(color: c.muted, fontSize: 10)),
      ],
    )),
    if (action != null) action,
  ]);

  Widget _dailyBookings(
      AppThemeColors c, ReservationDailySummary summary) => AppSurface(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(c, Icons.event_note_outlined, 'حجوزات اليوم',
          'كشف واحد لتجهيز الطلبات بدلاً من الاتصالات'),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            key: const Key('booking_date'),
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_today_rounded, size: 15),
            label: Text(_formatDay(_day), style: const TextStyle(fontSize: 11)),
          )),
          const SizedBox(width: 9),
          Expanded(child: FilledButton.icon(
            key: const Key('booking_add_quick'),
            onPressed: _addBooking,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('حجز سريع', style: TextStyle(fontSize: 12)),
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _miniMetric(c, 'الحجوزات النشطة', '${summary.activeCount}',
              Icons.receipt_long_rounded),
          const SizedBox(width: 7),
          _miniMetric(c, 'الربطات المطلوبة', '${summary.totalBundles}',
              Icons.eco_outlined),
          const SizedBox(width: 7),
          _miniMetric(c, 'جاهز للاستلام', '${summary.readyCount}',
              Icons.task_alt_rounded),
        ]),
        const SizedBox(height: 12),
        if (summary.orders.isEmpty)
          _empty(c, Icons.calendar_month_outlined,
              'لا توجد حجوزات لهذا اليوم',
              'أضف أول حجز وسيظهر في كشف التجهيز.')
        else
          for (final order in summary.orders) ...[
            _bookingRow(c, order),
            const SizedBox(height: 7),
          ],
        if (summary.bundlesByItem.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final group in summary.bundlesByItem.entries)
              Chip(
                label: Text('${group.key}: ${group.value} ربطة',
                    style: const TextStyle(fontSize: 10)),
                backgroundColor: c.pale,
                side: BorderSide(color: c.cardBorder),
              ),
          ]),
        ],
        const SizedBox(height: 7),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('booking_export_pdf'),
            onPressed: _exporting ? null : () => _exportBookings(summary),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_exporting
                ? 'جارٍ إعداد الكشف' : 'استخراج كشف التجهيز اليومي PDF',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        Text('مسودة الجهاز فقط • لا توجد حجوزات متزامنة من العملاء بعد.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: c.muted)),
      ],
    ),
  );

  Widget _miniMetric(
    AppThemeColors c, String title, String value, IconData icon) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: c.background,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.petrol, size: 16),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(
            fontWeight: FontWeight.w900, color: c.text, fontSize: 20)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: TextStyle(
              color: c.muted, fontSize: 10)),
          ),
        ],
      ),
    ));

  Widget _bookingRow(AppThemeColors c, ReservationDraft order) {
    final active = order.status != ReservationStatus.cancelled &&
        order.status != ReservationStatus.collected;
    return Container(
      key: Key('booking_row_${order.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: c.background,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(
          radius: 18, backgroundColor: c.pale,
          child: Icon(Icons.shopping_bag_outlined,
              color: c.petrol, size: 19)),
        const SizedBox(width: 7),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.customerName, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.text, fontSize: 12,
                  fontWeight: FontWeight.w900)),
            Text('${order.item} • ${order.bundles} ربطة • ${order.pickupTime}',
              style: TextStyle(color: c.muted, fontSize: 10)),
            Text(order.status.label, style: TextStyle(
              color: active ? c.pendingText : c.success,
              fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        )),
        PopupMenuButton<ReservationStatus>(
          tooltip: 'حالة الحجز المحلي',
          onSelected: (status) => setState(() {
            final index = _draftBookings.indexWhere((b) => b.id == order.id);
            if (index >= 0) {
              _draftBookings[index] = order.withStatus(status);
            }
          }),
          itemBuilder: (_) => [
            for (final status in ReservationStatus.values)
              PopupMenuItem(value: status, child: Text(
                status.label, style: const TextStyle(fontSize: 12))),
          ],
          icon: Icon(Icons.more_vert_rounded, color: c.petrol),
        ),
      ]),
    );
  }

  Widget _empty(AppThemeColors c, IconData icon, String title,
      String subtitle) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 19, horizontal: 10),
    decoration: BoxDecoration(
      color: c.background,
      border: Border.all(color: c.cardBorder),
      borderRadius: BorderRadius.circular(13)),
    child: Column(children: [
      Icon(icon, color: c.muted, size: 27),
      const SizedBox(height: 7),
      Text(title, style: TextStyle(
        color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(subtitle, textAlign: TextAlign.center,
        style: TextStyle(color: c.muted, fontSize: 10)),
    ]),
  );

  Widget _studio(AppThemeColors c) => AppSurface(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(c, Icons.movie_creation_outlined, 'استوديو التاجر',
          'صور يومية وفيديوهات للترويج للبضاعة'),
        const SizedBox(height: 13),
        Row(children: [
          _studioTile(c, Icons.add_photo_alternate_outlined,
              'إضافة صور', AppColors.success, () => _chooseMedia(false)),
          const SizedBox(width: 9),
          _studioTile(c, Icons.video_call_outlined,
              'إضافة فيديو', AppColors.sea, () => _chooseMedia(true)),
        ]),
        const SizedBox(height: 10),
        if (_studioDrafts.isEmpty)
          Text('لم تُضف وسائط بعد. تظهر منشوراتك المحفوظة بعد ربط الاستوديو.',
            style: TextStyle(color: c.muted, fontSize: 11))
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _studioDrafts.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _studioDrafts[index];
                return Container(
                  width: 110, padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: c.background,
                    border: Border.all(color: c.cardBorder),
                    borderRadius: BorderRadius.circular(11)),
                  child: Column(children: [
                    SizedBox(
                      height: 51, width: double.infinity,
                      child: item.image != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.memory(item.image!,
                                fit: BoxFit.cover))
                          : Icon(Icons.play_circle_outline_rounded,
                            color: c.petrol, size: 36),
                    ),
                    const SizedBox(height: 4),
                    Text(item.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.text, fontSize: 9)),
                    Text('مسودة',
                      style: TextStyle(color: c.pendingText, fontSize: 9)),
                  ]),
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.send_outlined, color: c.petrol, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(
            'مشاركة الصور والفيديوهات مع العملاء بعد النشر '
            'وتفعيل الموافقات على التنبيهات.',
            style: TextStyle(color: c.muted, fontSize: 10))),
        ]),
      ],
    ),
  );

  Widget _studioTile(AppThemeColors c, IconData icon, String label,
      Color color, VoidCallback action) => Expanded(child: Material(
    color: color.withValues(alpha: .09),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: Key(label == 'إضافة صور' ? 'studio_add_photo' : 'studio_add_video'),
      onTap: action,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 87,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: .24)),
          borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 27),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ),
  ));

  Widget _broadcast(AppThemeColors c) {
    final people = MerchantAudienceQuery.eligible(
      merchantId: widget.merchantId,
      customers: widget.state.customers.value,
      relationships: widget.state.relationships.value,
      movements: widget.state.movements.value,
      audience: _audience,
    );
    return AppSurface(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(c, Icons.campaign_outlined, 'تنبيهات العملاء',
            'رسائل دقيقة حسب الفئة، دون إزعاج'),
          const SizedBox(height: 12),
          SizedBox(height: 36, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: BroadcastAudience.values.length,
            separatorBuilder: (_, index) => const SizedBox(width: 7),
            itemBuilder: (context, i) {
              final kind = BroadcastAudience.values[i];
              final selected = _audience == kind;
              return ChoiceChip(
                key: Key('broadcast_${kind.name}'),
                showCheckmark: false,
                selected: selected,
                selectedColor: c.pale,
                backgroundColor: c.card,
                side: BorderSide(
                  color: selected ? c.petrol : c.cardBorder),
                label: Text(kind.label, style: TextStyle(
                  color: selected ? c.petrol : c.text,
                  fontSize: 11, fontWeight: FontWeight.w700)),
                onSelected: (_) => setState(() => _audience = kind),
              );
            },
          )),
          const SizedBox(height: 10),
          Row(children: [
            Text('المستهدفون: ${people.length}', style: TextStyle(
              color: c.petrol, fontSize: 12,
              fontWeight: FontWeight.w900)),
            const Spacer(),
            Text('العلاقات المعتمدة فقط',
              style: TextStyle(color: c.muted, fontSize: 10)),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const Key('broadcast_template'),
            value: _noticeKind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع التنبيه'),
            items: [
              for (final kind in _templates.keys)
                DropdownMenuItem(value: kind,
                    child: Text(kind, style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _noticeKind = v;
                _notifications.text = _templates[v] ?? '';
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('broadcast_message'),
            controller: _notifications,
            minLines: 2, maxLines: 4,
            maxLength: 280,
            decoration: const InputDecoration(
              hintText: 'اكتب التنبيه الذي تريد إرساله لعملائك...',
            ),
          ),
          SizedBox(width: double.infinity,
            child: FilledButton.icon(
              key: const Key('broadcast_review'),
              onPressed: () => _previewNotification(people.length),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('مراجعة التنبيه قبل الإرسال'),
            ),
          ),
          Text('الإرسال الفعلي لم يُفعّل بعد؛ '
              'سيتطلب موافقة التلقي ومنع تكرار الرسائل.',
            style: TextStyle(color: c.muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _engagement(AppThemeColors c) => AppSurface(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(c, Icons.analytics_outlined, 'تفاعل الجمهور',
            'ما الذي يشاهده عملاؤك ويتفاعلون معه؟'),
        const SizedBox(height: 13),
        Row(children: [
          _engagementMetric(c, 'المشاهدات', Icons.visibility_outlined),
          const SizedBox(width: 7),
          _engagementMetric(c, 'الإعجابات', Icons.favorite_border_rounded),
          const SizedBox(width: 7),
          _engagementMetric(c, 'المشاركات', Icons.ios_share_outlined),
        ]),
        const SizedBox(height: 11),
        _empty(c, Icons.insights_rounded,
          'الأكثر مشاهدة ومشاركة',
          'لا توجد إحصاءات منشورة بعد. سيظهر ترتيب المحتوى '
          'عند توفر بيانات مشاهدة ومشاركة حقيقية.'),
      ],
    ),
  );

  Widget _engagementMetric(AppThemeColors c, String title,
      IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: c.background,
      border: Border.all(color: c.cardBorder),
      borderRadius: BorderRadius.circular(11)),
    child: Column(children: [
      Icon(icon, color: c.petrol, size: 19),
      const SizedBox(height: 6),
      Text('—', style: TextStyle(
        color: c.text, fontWeight: FontWeight.w900, fontSize: 20)),
      Text(title, style: TextStyle(color: c.muted, fontSize: 10)),
    ]),
  ));
  Widget _ratings(AppThemeColors c) {
    // Live scores are not present without authenticated, verified reviews.
    final summary = MerchantReviewPolicy.summarize(
        widget.merchantId ?? '', const <MerchantReview>[]);
    return AppSurface(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(c, Icons.star_border_rounded, 'تقييمات المتجر',
              'آراء مشترين حقيقيين بعد عملية شراء معتمدة'),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.star_rounded, color: c.pendingText, size: 27),
            const SizedBox(width: 7),
            Text(summary.average == null ? '—'
                : summary.average!.toStringAsFixed(1),
              style: TextStyle(color: c.text,
                fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(width: 9),
            Text('${summary.publishedCount} تقييم موثق',
              style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 9),
          Text(
            'بعد إتمام شراء حقيقي، يستطيع العميل تقييم التاجر من '
            'نجمة إلى خمس نجوم وكتابة مراجعة. تقييم واحد لكل عميل '
            'قابل للتحديث، وتُنشر النتائج بعد التحقق والمراجعة.',
            style: TextStyle(color: c.muted, fontSize: 11, height: 1.55),
          ),
          const SizedBox(height: 8),
          Text('الظهور في قائمة الأعلى تقييماً يحتاج 5 تقييمات '
              'موثقة على الأقل؛ لا تأثير للباقات على النزاهة.',
            style: TextStyle(color: c.petrol,
              fontWeight: FontWeight.w700, fontSize: 11)),
        ],
      ),
    );
  }

}
