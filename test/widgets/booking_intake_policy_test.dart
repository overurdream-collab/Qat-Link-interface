import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/merchant_space/booking_intake_policy.dart';

final now = DateTime.utc(2026, 11, 15, 10); // 13:00 in Sana'a.
final tomorrow = DateTime.utc(2026, 11, 16);

CustomerModel client(String id, {bool active = true}) => CustomerModel(
  id: id, name: 'عميل $id', phone: '771234567',
  primaryCurrency: CurrencyCode.yer,
  createdAt: now, updatedAt: now,
  accountStatus: active ? AccountStatus.active : AccountStatus.suspended,
);

RelationshipModel link(String id, {bool approved = true,
    String merchantId = 'm1'}) => RelationshipModel(
  id: 'rel-$id', merchantId: merchantId, customerId: id,
  createdBy: merchantId, createdByRole: ParticipantRole.merchant,
  createdAt: now,
  approvals: [
    ApprovalRecord(actorId: merchantId, role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: now),
    if (approved) ApprovalRecord(actorId: id,
      role: ParticipantRole.customer,
      decision: ApprovalDecision.approved, decidedAt: now),
  ],
);

BookingEligibility gate({
  String? merchantId = 'm1',
  String? customerId = 'c1',
  BookingIntakeSettings settings = const BookingIntakeSettings(
    enabled: true, allDay: true,
  ),
  DateTime? at,
  DateTime? day,
  Iterable<RelationshipModel>? relationships,
  Iterable<CustomerModel>? customers,
}) => BookingIntakePolicy.check(
  settings: settings, merchantId: merchantId, customerId: customerId,
  customers: customers ?? [client('c1'), client('c2')],
  relationships: relationships ?? [link('c1'), link('c2',approved:false)],
  now: at ?? now, bookingDay: day ?? tomorrow,
);

void main() {
  test('no anonymous, unlinked, pending-linked or suspended customer booking', () {
    expect(gate(merchantId: null).allowed, false);
    expect(gate(customerId: null).allowed, false);
    expect(gate(customerId: 'c2').allowed, false);
    expect(gate(customerId: 'other').allowed, false);
    expect(gate(customers: [client('c1',active:false)]).allowed, false);
    expect(gate(relationships: [link('c1',merchantId:'m2')]).allowed, false);
    expect(gate().allowed, true);
  });

  test('closed gate always rejects even approved client, all-day opens fully', () {
    expect(gate(settings: const BookingIntakeSettings(
      enabled: false, allDay: true)).allowed, false);
    expect(gate(settings: const BookingIntakeSettings(
      enabled: true, allDay: true),
      at: DateTime.utc(2026,11,15,23)).allowed, true);
    expect(gate(day: DateTime.utc(2026,11,14)).allowed, false);
  });

  test('daily 08:00–20:00 window uses Sana\'a timezone and exclusive close', () {
    const config = BookingIntakeSettings(
      enabled:true, opensAtMinute:480, closesAtMinute:1200);
    expect(BookingIntakePolicy.isWindowOpen(config,
        DateTime.utc(2026,11,15,4,59)), false); // 07:59
    expect(BookingIntakePolicy.isWindowOpen(config,
        DateTime.utc(2026,11,15,5)), true); // 08:00
    expect(BookingIntakePolicy.isWindowOpen(config,
        DateTime.utc(2026,11,15,16,59)), true); // 19:59
    expect(BookingIntakePolicy.isWindowOpen(config,
        DateTime.utc(2026,11,15,17)), false); // 20:00
  });

  test('overnight 20:00–02:00 works either side of midnight', () {
    const config = BookingIntakeSettings(
      enabled:true, opensAtMinute:1200, closesAtMinute:120);
    expect(BookingIntakePolicy.isWindowOpen(config,
        DateTime.utc(2026,11,15,17)), true); // 20:00
    expect(BookingIntakePolicy.isWindowOpen(config,
        DateTime.utc(2026,11,15,22,30)), true); // 01:30 tomorrow
    expect(BookingIntakePolicy.isWindowOpen(config,
        DateTime.utc(2026,11,15,23)), false); // 02:00
    expect(BookingIntakePolicy.isWindowOpen(config,
        DateTime.utc(2026,11,15,10)), false);
  });

  test('same from-to is invalid unless 24 hour mode', () {
    const invalid = BookingIntakeSettings(
      enabled:true, opensAtMinute:540, closesAtMinute:540);
    expect(invalid.valid, false);
    expect(BookingIntakePolicy.isWindowOpen(invalid, now), false);
    expect(invalid.copyWith(allDay:true).valid, true);
  });

  test('nightly reminder reaches only active approved linked customers', () {
    const config = BookingNightReminderSettings(
      enabled:true, sendAtMinute:20*60+30);
    final preview = BookingNightReminderPolicy.preview(
      settings:config, merchantId:'m1',
      customers:[client('c1'), client('c2')],
      relationships:[link('c1'), link('c2', approved:false)],
      now:DateTime.utc(2026,11,15,17), // 20:00
    );
    expect(preview.recipientIds, ['c1']);
    expect(preview.bookingForDay.day, 16);
    expect(preview.sendAtSanaa.hour, 20);
    final disabled = BookingNightReminderPolicy.preview(
      settings:const BookingNightReminderSettings(),
      merchantId:'m1',
      customers:[client('c1')],
      relationships:[link('c1')], now:now,
    );
    expect(disabled.recipientIds, isEmpty);
    final anonymous = BookingNightReminderPolicy.preview(
      settings: config,
      merchantId:null, customers:[client('c1')],
      relationships:[link('c1')], now:now,
    );
    expect(anonymous.recipientIds, isEmpty);
  });
}
