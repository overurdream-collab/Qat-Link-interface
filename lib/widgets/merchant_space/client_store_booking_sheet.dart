import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_models.dart';
import '../../theme/app_colors.dart';
import 'booking_intake_policy.dart';

/// Customer-originated request. Only an authenticated customer in an approved
/// relationship can submit; server must repeat every check and persist.
class ClientBookingRequest {
  const ClientBookingRequest({
    required this.merchantId,
    required this.customerId,
    required this.day,
    required this.item,
    required this.bundles,
    required this.pickupTime,
  });

  final String merchantId;
  final String customerId;
  final DateTime day;
  final String item;
  final int bundles;
  final String pickupTime;
}

class ClientStoreBookingSheet extends StatefulWidget {
  const ClientStoreBookingSheet({
    super.key,
    required this.merchantId,
    required this.customerId,
    required this.intakeSettings,
    required this.customers,
    required this.relationships,
    this.onAuthenticatedSubmit,
  });
  final String? merchantId;
  /// MUST come from the server-authenticated session, not an editable input.
  final String? customerId;
  final BookingIntakeSettings intakeSettings;
  final List<CustomerModel> customers;
  final List<RelationshipModel> relationships;
  /// Must call backend which rechecks identity/consent/window/stock/limits.
  final Future<bool> Function(ClientBookingRequest request)?
      onAuthenticatedSubmit;

  @override
  State<ClientStoreBookingSheet> createState() =>
      _ClientStoreBookingSheetState();
}

class _ClientStoreBookingSheetState extends State<ClientStoreBookingSheet> {
  final _form = GlobalKey<FormState>();
  final _item = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _pickup = TextEditingController(text: '11:00');
  late DateTime _day;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final sanaa = BookingIntakePolicy.sanaaTime(DateTime.now());
    _day = DateTime(sanaa.year, sanaa.month, sanaa.day + 1);
  }

  @override
  void dispose() {
    _item.dispose(); _quantity.dispose(); _pickup.dispose();
    super.dispose();
  }

  BookingEligibility get _eligibility => BookingIntakePolicy.check(
    settings: widget.intakeSettings,
    merchantId: widget.merchantId,
    customerId: widget.customerId,
    customers: widget.customers,
    relationships: widget.relationships,
    now: DateTime.now(),
    bookingDay: _day,
  );

  Future<void> _pickDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2025),
      lastDate: DateTime(2100),
      helpText: 'اختيار يوم الاستلام',
    );
    if (!mounted || date == null) return;
    setState(() => _day = date);
  }

  Future<void> _submit() async {
    if (_busy || _form.currentState?.validate() != true) return;
    final eligibility = _eligibility;
    if (!eligibility.allowed ||
        widget.onAuthenticatedSubmit == null ||
        widget.merchantId == null ||
        widget.customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eligibility.allowed
            ? 'الحجز ينتظر الربط بالخادم الموثق؛ لم يُرسل أي طلب.'
            : eligibility.reason),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final accepted = await widget.onAuthenticatedSubmit!(
        ClientBookingRequest(
          merchantId: widget.merchantId!,
          customerId: widget.customerId!,
          day: _day,
          item: _item.text.trim(),
          bundles: int.parse(_quantity.text),
          pickupTime: _pickup.text,
        ),
      );
      if (!mounted) return;
      if (accepted) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الخادم لم يؤكد الحجز. لم يُسجل أي طلب.'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر إرسال الحجز. أعد المحاولة بعد التحقق من الاتصال.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final eligibility = _eligibility;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            17, 10, 17, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: SingleChildScrollView(child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('احجز طلبك للغد', style: TextStyle(
                color: c.petrol, fontSize: 19,
                fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('الحجز متاح فقط لعملاء هذا التاجر المعتمدين.',
                  style: TextStyle(color: c.muted, fontSize: 11)),
              const SizedBox(height: 13),
              OutlinedButton.icon(
                key: const Key('client_booking_day'),
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('${_day.year}/${_day.month}/${_day.day}'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('client_booking_item'),
                controller: _item,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'الصنف المطلوب'),
                validator: (text) => (text ?? '').trim().isEmpty
                    ? 'حدد الصنف' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('client_booking_bundles'),
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'عدد الربطات'),
                validator: (raw) {
                  final n = int.tryParse(raw ?? '');
                  return n == null || n < 1 || n > 10000
                      ? 'الكمية من 1 إلى 10000' : null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('client_booking_pickup'),
                controller: _pickup,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'موعد الاستلام', hintText: '11:00'),
                validator: (raw) =>
                    RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$')
                        .hasMatch(raw ?? '')
                    ? null : 'استخدم التنسيق 11:00',
              ),
              const SizedBox(height: 10),
              if (!eligibility.allowed)
                Text(eligibility.reason, style: TextStyle(
                  color: c.danger, fontWeight: FontWeight.w700,
                  fontSize: 12)),
              if (eligibility.allowed &&
                  widget.onAuthenticatedSubmit == null)
                Text('إرسال الحجز غير متصل بالخادم بعد.',
                    style: TextStyle(color: c.pendingText, fontSize: 11)),
              const SizedBox(height: 11),
              FilledButton.icon(
                key: const Key('client_booking_submit'),
                onPressed: eligibility.allowed && !_busy &&
                        widget.onAuthenticatedSubmit != null
                    ? _submit : null,
                icon: const Icon(Icons.event_available_outlined),
                label: Text(_busy ? 'جارٍ الإرسال' : 'إرسال طلب الحجز'),
              ),
            ],
          ),
        )),
      ),
    );
  }
}
