import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/merchant_space/merchant_space_models.dart';

final now = DateTime(2026, 11, 15);

CustomerModel customer(String id, String name) => CustomerModel(
  id: id,
  name: name,
  phone: '77${id == 'c1' ? '1234567' : '3214567'}',
  primaryCurrency: CurrencyCode.yer,
  createdAt: now, updatedAt: now,
);

RelationshipModel relationship(String merchant, String customerId,
    {bool approved = true}) => RelationshipModel(
  id: 'r_$merchant-$customerId',
  merchantId: merchant, customerId: customerId,
  createdBy: merchant, createdByRole: ParticipantRole.merchant,
  createdAt: now,
  approvals: [
    ApprovalRecord(actorId: merchant, role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: now),
    if (approved)
      ApprovalRecord(actorId: customerId, role: ParticipantRole.customer,
        decision: ApprovalDecision.approved, decidedAt: now),
  ],
);

MovementModel movement({
  required String id,
  required String merchant,
  required String customerId,
  required CurrencyCode currency,
  required String amount,
  required MovementType type,
  required MovementStatus status,
}) => MovementModel(
  id: id,
  relationshipId: 'r_$merchant-$customerId',
  customerId: customerId, merchantId: merchant,
  amount: Decimal.parse(amount),
  currency: currency, type: type,
  createdBy: merchant, createdByRole: ParticipantRole.merchant,
  createdAt: now,
  approvals: [
    ApprovalRecord(actorId: merchant, role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: now),
    if (status != MovementStatus.pending)
      ApprovalRecord(actorId: customerId, role: ParticipantRole.customer,
        decision: status == MovementStatus.approved
          ? ApprovalDecision.approved : ApprovalDecision.rejected,
        decidedAt: now),
  ],
);

ReservationDraft booking(String id, int bundles, String item,
    ReservationStatus status, {
    DateTime? day,
    String time = '10:00',
}) => ReservationDraft(
  id: id, customerName: 'عميل $id',
  phone: '771234567',
  item: item, bundles: bundles, day: day ?? now,
  pickupTime: time, createdAt: now, status: status,
);

void main() {
  test('daily summary groups active bundles by qat variety and orders by pickup time', () {
    final orders = [
      booking('b3', 2, 'قات حاشدي', ReservationStatus.ready, time: '14:00'),
      booking('b1', 3, 'قات حاشدي', ReservationStatus.confirmed, time: '09:00'),
      booking('b4', 10, 'قات همداني', ReservationStatus.cancelled),
      booking('b2', 4, 'قات همداني', ReservationStatus.awaitingConfirmation),
      booking('otherday', 8, 'قات حاشدي', ReservationStatus.confirmed,
          day: DateTime(2026, 11, 14)),
    ];
    final s = ReservationsQuery.forDay(orders, now);
    expect(s.orders, hasLength(4));
    expect(s.orders.first.id, 'b1');
    expect(s.activeCount, 3);
    expect(s.totalBundles, 9);
    expect(s.readyCount, 1);
    expect(s.bundlesByItem, {'قات حاشدي': 5, 'قات همداني': 4});
  });

  test('collected orders are excluded from outstanding preparation', () {
    final result = ReservationsQuery.forDay([
      booking('ready', 7, 'حاشدي', ReservationStatus.collected),
      booking('active', 2, 'همداني', ReservationStatus.preparing),
    ], now);
    expect(result.orders, hasLength(2));
    expect(result.totalBundles, 2);
    expect(result.activeCount, 1);
  });

  test('broadcast audience requires approved relationship and merchant context', () {
    final customers = [customer('c1', 'علي'), customer('c2', 'صالح')];
    final rels = [
      relationship('m1', 'c1'),
      relationship('m1', 'c2', approved: false),
      relationship('m2', 'c2'),
    ];
    final moves = [
      movement(id: 'approvedYER', merchant: 'm1', customerId: 'c1',
        currency: CurrencyCode.yer, amount: '50', type: MovementType.debt,
        status: MovementStatus.approved),
      movement(id: 'pendingUSD', merchant: 'm1', customerId: 'c1',
        currency: CurrencyCode.usd, amount: '300', type: MovementType.debt,
        status: MovementStatus.pending),
      movement(id: 'unapproved', merchant: 'm1', customerId: 'c2',
        currency: CurrencyCode.yer, amount: '1000', type: MovementType.debt,
        status: MovementStatus.approved),
    ];
    List<CustomerModel> query(String? merchant, BroadcastAudience audience) =>
      MerchantAudienceQuery.eligible(
        merchantId: merchant, customers: customers,
        relationships: rels, movements: moves, audience: audience,
      );
    expect(query('m1', BroadcastAudience.all).map((c) => c.id), ['c1']);
    expect(query('m1', BroadcastAudience.unpaid).map((c) => c.id), ['c1']);
    expect(query('m1', BroadcastAudience.pending).map((c) => c.id), ['c1']);
    expect(query(null, BroadcastAudience.all), isEmpty);
    expect(query('', BroadcastAudience.all), isEmpty);
    expect(query('other', BroadcastAudience.all), isEmpty);
    expect(query('m2', BroadcastAudience.all).map((c) => c.id), ['c2']);
  });

  test('overpayment credit never puts a customer in unpaid segment', () {
    final rels = [relationship('m1', 'c1')];
    final moves = [
      movement(id: 'debt', merchant: 'm1', customerId: 'c1',
        currency: CurrencyCode.yer, amount: '100', type: MovementType.debt,
        status: MovementStatus.approved),
      movement(id: 'payment', merchant: 'm1', customerId: 'c1',
        currency: CurrencyCode.yer, amount: '120', type: MovementType.payment,
        status: MovementStatus.approved),
    ];
    final clients = MerchantAudienceQuery.eligible(
      merchantId: 'm1', customers: [customer('c1', 'علي')],
      relationships: rels, movements: moves,
      audience: BroadcastAudience.unpaid);
    expect(clients, isEmpty);
  });
}
