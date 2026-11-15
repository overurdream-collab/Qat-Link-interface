import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../theme/app_colors.dart';
import 'booking_intake_policy.dart';
import 'night_reminder_campaign.dart';

/// Customer reminder -> confirmed booking with ONE editable field: quantity.
/// This can only be mounted from a server-authenticated reminder deep link.
/// Never invent a confirmed booking in local AppState.
class ReminderQuickBookingSheet extends StatefulWidget {
  const ReminderQuickBookingSheet({
    super.key,
    required this.campaign,
    required this.authenticatedCustomerId,
    required this.verifiedDeliveredCustomerIds,
    required this.intakeSettings,
    required this.customers,
    required this.relationships,
    this.onServerConfirm,
  });
  final NightReminderCampaignDraft campaign;
  final String? authenticatedCustomerId;
  final Set<String> verifiedDeliveredCustomerIds;
  final BookingIntakeSettings intakeSettings;
  final List<CustomerModel> customers;
  final List<RelationshipModel> relationships;

  /// Must call authenticated backend; return true ONLY after booking persisted
  /// and its status is confirmed, not after accepting a queue request.
  final Future<bool> Function(ReminderQuickBookingRequest request)?
      onServerConfirm;

  @override
  State<ReminderQuickBookingSheet> createState() =>
      _ReminderQuickBookingSheetState();
}

class _ReminderQuickBookingSheetState extends State<ReminderQuickBookingSheet> {
  bool _showQuantityStep = false;
  int _quantity = 1;
  bool _busy = false;
  ReminderBookingDecision get _policy => ReminderQuickBookingPolicy.check(
    campaign: widget.campaign,
    authenticatedCustomerId: widget.authenticatedCustomerId,
    quantity: _quantity,
    verifiedDeliveredCustomerIds: widget.verifiedDeliveredCustomerIds,
    intakeSettings: widget.intakeSettings,
    customers: widget.customers,
    relationships: widget.relationships,
    now: DateTime.now(),
  );

  Future<void> _confirm() async {
    if (_busy || widget.onServerConfirm == null) return;
    final decision = _policy;
    if (!decision.allowed || widget.authenticatedCustomerId == null) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.onServerConfirm!(
        ReminderQuickBookingRequest(
          campaignId: widget.campaign.id,
          merchantId: widget.campaign.merchantId,
          customerId: widget.authenticatedCustomerId!,
          day: widget.campaign.day,
          item: widget.campaign.offeredItem,
          pickupTime: widget.campaign.pickupTime,
          quantity: _quantity,
        ),
      );
      if (!mounted) return;
      if (saved) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('لم يؤكد الخادم الحجز. لم تُنشأ حجوزات مؤكدة.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تأكيد الحجز. أعد المحاولة بعد التحقق من الاتصال.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final decision = _policy;
    final canConfirm = decision.allowed &&
        widget.onServerConfirm != null && !_busy;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(Icons.event_available_rounded, color: c.petrol, size: 29),
                const SizedBox(width: 9),
                Expanded(child: Text('تذكير بحجز الغد',
                  style: TextStyle(color: c.text,
                    fontSize: 19, fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 13),
              Text(widget.campaign.offeredItem,
                style: TextStyle(color: c.petrol,
                  fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('موعد الاستلام: ${widget.campaign.pickupTime}',
                style: TextStyle(color: c.muted)),
              const SizedBox(height: 12),
              if (!decision.allowed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(decision.reason,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.danger, fontSize: 11)),
                ),
              if (!_showQuantityStep) ...[
                Text('هل ترغب في تأكيد حجزك للغد؟',
                  style: TextStyle(color: c.text,
                    fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: FilledButton.icon(
                    key: const Key('reminder_start_booking'),
                    onPressed: decision.allowed && !_busy
                        ? () => setState(() => _showQuantityStep = true)
                        : null,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('تأكيد الحجز'),
                  )),
                  const SizedBox(width: 9),
                  Expanded(child: OutlinedButton.icon(
                    key: const Key('reminder_ignore'),
                    onPressed: _busy
                        ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('تجاهل'),
                  )),
                ]),
              ] else ...[
                Text('كم ربطة تريد؟', style: TextStyle(
                  color: c.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton.filledTonal(
                    key: const Key('reminder_quantity_minus'),
                    tooltip: 'إنقاص العدد',
                    onPressed: _quantity <= 1 || _busy ? null
                        : () => setState(() => _quantity--),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  const SizedBox(width: 18),
                  Text('$_quantity', key: const Key('reminder_quantity'),
                    style: TextStyle(color: c.petrol,
                      fontSize: 34, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 18),
                  IconButton.filledTonal(
                    key: const Key('reminder_quantity_plus'),
                    tooltip: 'زيادة العدد',
                    onPressed: _quantity >= 10000 || _busy ? null
                        : () => setState(() => _quantity++),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ]),
                const SizedBox(height: 14),
                if (decision.allowed && widget.onServerConfirm == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Text('التأكيد الفعلي ينتظر ربط خادم الحجوزات.',
                      style: TextStyle(color: c.pendingText, fontSize: 11)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('reminder_confirm_booking'),
                    onPressed: canConfirm ? _confirm : null,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(_busy ? 'جارٍ التأكيد' : 'تأكيد الحجز'),
                  ),
                ),
                TextButton(
                  key: const Key('reminder_back_to_invitation'),
                  onPressed: _busy ? null
                      : () => setState(() => _showQuantityStep = false),
                  child: const Text('العودة إلى التذكير'),
                ),
              ],
              const SizedBox(height: 6),
              Text('الحجز لا ينشئ ديناً. أي دين لاحق يحتاج '
                  'طلباً من التاجر وموافقتك عليه.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
