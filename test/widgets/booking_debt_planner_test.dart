import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/merchant_space/booking_debt_planner.dart';
import 'package:qat_link/widgets/merchant_space/merchant_space_models.dart';

final day = DateTime(2026, 11, 15);

CustomerModel customer(String id, {bool active = true}) => CustomerModel(
  id: id, name: id,
  phone: '77${id == 'c1' ? '1234567' : '3214567'}',
  primaryCurrency: CurrencyCode.yer,
  createdAt: day, updatedAt: day,
  accountStatus: active ? AccountStatus.active : AccountStatus.suspended,
);

RelationshipModel relation(String id, String merchant,
    {bool approved = true}) => RelationshipModel(
  id: 'r-$merchant-$id',
  merchantId: merchant, customerId: id,
  createdBy: merchant, createdByRole: ParticipantRole.merchant,
  createdAt: day,
  approvals: [
    ApprovalRecord(actorId: merchant, role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: day),
    if (approved)
      ApprovalRecord(actorId: id, role: ParticipantRole.customer,
        decision: ApprovalDecision.approved, decidedAt: day),
  ],
);

ReservationDraft booking(String id, {
  String? customerId = 'c1',
  ReservationStatus status = ReservationStatus.collected,
  BookingSettlement settlement = BookingSettlement.unpaid,
  CurrencyCode currency = CurrencyCode.yer,
  String? price = '45.25',
  int bundles = 2,
}) => ReservationDraft(
  id: id, customerName: 'عميل $id',
  phone: '771234567',
  item: 'قات حاشدي',
  bundles: bundles, day: day,
  pickupTime: '11:00', createdAt: day,
  customerId: customerId,
  currency: currency, status: status, settlement: settlement,
  unitPrice: price == null ? null : Decimal.parse(price),
);

void main() {
  final customers = [customer('c1'), customer('c2')];
  final relationships = [
    relation('c1', 'm1'),
    relation('c2', 'm1', approved: false),
    relation('c2', 'm2'),
  ];

  BookingDebtPlan plan(
      List<ReservationDraft> source, Set<String> ids, {
      String? merchantId = 'm1',
      Set<String> submitted = const {},
  }) => BookingDebtPlanner.build(
    merchantId: merchantId, bookings: source, selectedIds: ids,
    relationships: relationships, customers: customers,
    alreadySubmittedBookingIds: submitted,
  );

  test('one click builds separate requests per customer and currency', () {
    final orders = [
      booking('a', price: '15.25', bundles: 2),
      booking('b', price: '7', bundles: 4),
      booking('c', currency: CurrencyCode.sar, price: '2', bundles: 3),
    ];
    final result = plan(orders, {'a','b','c'});
    expect(result.includedBookings, 3);
    expect(result.requests.length, 2);
    final yer = result.requests.singleWhere((r) => r.currency == CurrencyCode.yer);
    expect(yer.amount, Decimal.parse('58.50'));
    expect(yer.bookingIds, containsAll(['a','b']));
    expect(yer.customerId, 'c1');
    final sar = result.requests.singleWhere((r) => r.currency == CurrencyCode.sar);
    expect(sar.amount, Decimal.parse('6'));
    expect(result.skipped, isEmpty);
    expect(yer.idempotencyKey, contains('a,b'));
  });

  test('strictly excludes paid, not-collected, unpriced, and unlinked bookings', () {
    final orders = [
      booking('paid', settlement: BookingSettlement.paid),
      booking('unknown', settlement: BookingSettlement.unknown),
      booking('notCollected', status: ReservationStatus.ready),
      booking('noPrice', price: null),
      booking('noAccount', customerId: null),
      booking('unapproved', customerId: 'c2'),
      booking('eligible'),
    ];
    final result = plan(orders, orders.map((b) => b.id).toSet());
    expect(result.includedBookings, 1);
    expect(result.requests.single.bookingIds, ['eligible']);
    expect(result.skipped.length, 6);
    expect(result.skipped['unapproved'], contains('معتمدة'));
  });

  test('tenant fail-closed, replay protection and subsets are deterministic', () {
    final source = [booking('a'), booking('b')];
    expect(plan(source, {'a'}, merchantId: null).requests, isEmpty);
    expect(plan(source, {'a'}, merchantId: 'm2').requests, isEmpty);
    final replay = plan(source, {'a','b'}, submitted: {'a'});
    expect(replay.skipped['a'], contains('سابق'));
    expect(replay.requests.single.bookingIds, ['b']);
  });

  test('proposals count only collected orders with a price, per currency', () {
    final source = [
      booking('yer', price: '1.25', bundles: 3,
          settlement: BookingSettlement.paid),
      booking('sar', currency: CurrencyCode.sar, price: '5', bundles: 2),
      booking('pending', status: ReservationStatus.confirmed, price: '999'),
      booking('missing', price: null),
    ];
    final totals = BookingProposalQuery.calculate(source, day);
    expect(totals.collectedCount, 3);
    expect(totals.missingPriceCount, 1);
    expect(totals.byCurrency[CurrencyCode.yer], Decimal.parse('3.75'));
    expect(totals.byCurrency[CurrencyCode.sar], Decimal.parse('10'));
    expect(totals.paidByCurrency[CurrencyCode.yer], Decimal.parse('3.75'));
    expect(totals.unpaidByCurrency[CurrencyCode.sar], Decimal.parse('10'));
    expect(totals.byCurrency.containsKey(CurrencyCode.usd), false);
  });
}
