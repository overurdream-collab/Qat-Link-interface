import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/customers/customer_statement_calculator.dart';

final _january = DateTime(2026, 1, 1);
final _merchantId = 'merchant-1';

RelationshipModel _relationship(String customerId, String merchantId,
    {bool approved = true}) => RelationshipModel(
  id: 'r_$customerId-$merchantId',
  merchantId: merchantId,
  customerId: customerId,
  createdBy: merchantId,
  createdByRole: ParticipantRole.merchant,
  createdAt: _january,
  approvals: [
    ApprovalRecord(actorId: merchantId, role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: _january),
    if (approved)
      ApprovalRecord(actorId: customerId, role: ParticipantRole.customer,
        decision: ApprovalDecision.approved, decidedAt: _january),
  ],
);

MovementModel _movement({
  required String id,
  required String customerId,
  required String merchantId,
  required CurrencyCode currency,
  required String amount,
  required MovementType type,
  required MovementStatus status,
  required DateTime createdAt,
}) => MovementModel(
  id: id,
  relationshipId: 'r_$customerId-$merchantId',
  customerId: customerId,
  merchantId: merchantId,
  amount: Decimal.parse(amount),
  currency: currency,
  type: type,
  createdBy: merchantId,
  createdByRole: ParticipantRole.merchant,
  createdAt: createdAt,
  approvals: [
    ApprovalRecord(actorId: merchantId, role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: createdAt),
    if (status != MovementStatus.pending)
      ApprovalRecord(actorId: customerId, role: ParticipantRole.customer,
        decision: status == MovementStatus.approved
            ? ApprovalDecision.approved : ApprovalDecision.rejected,
        decidedAt: createdAt),
  ],
);

void main() {
  final relationships = [
    _relationship('c1', _merchantId),
    _relationship('c1', 'merchant-2'),
    _relationship('c2', _merchantId, approved: false),
  ];
  final movements = [
    _movement(id: 'opening-debt', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer, amount: '50000',
      type: MovementType.debt, status: MovementStatus.approved,
      createdAt: DateTime(2026, 1, 31, 10)),
    _movement(id: 'opening-payment', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer, amount: '15000',
      type: MovementType.payment, status: MovementStatus.approved,
      createdAt: DateTime(2026, 1, 31, 15)),
    _movement(id: 'opening-pending', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer, amount: '12000',
      type: MovementType.debt, status: MovementStatus.pending,
      createdAt: DateTime(2026, 1, 31)),
    _movement(id: 'period-debt', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer, amount: '90000.75',
      type: MovementType.debt, status: MovementStatus.approved,
      createdAt: DateTime(2026, 2, 1, 0, 0)),
    _movement(id: 'period-payment', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer, amount: '25000',
      type: MovementType.payment, status: MovementStatus.approved,
      createdAt: DateTime(2026, 2, 28, 23, 59)),
    _movement(id: 'period-pending', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer, amount: '7777',
      type: MovementType.debt, status: MovementStatus.pending,
      createdAt: DateTime(2026, 2, 15)),
    _movement(id: 'period-rejected', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer, amount: '999999',
      type: MovementType.debt, status: MovementStatus.rejected,
      createdAt: DateTime(2026, 2, 16)),
    _movement(id: 'next-month', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer, amount: '6500',
      type: MovementType.debt, status: MovementStatus.approved,
      createdAt: DateTime(2026, 3, 1)),
    _movement(id: 'sar-debt', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.sar, amount: '350',
      type: MovementType.debt, status: MovementStatus.approved,
      createdAt: DateTime(2026, 2, 7)),
    _movement(id: 'other-merchant', customerId: 'c1',
      merchantId: 'merchant-2', currency: CurrencyCode.yer,
      amount: '888888', type: MovementType.debt,
      status: MovementStatus.approved, createdAt: DateTime(2026, 2, 8)),
    _movement(id: 'unapproved-relation', customerId: 'c2',
      merchantId: _merchantId, currency: CurrencyCode.yer,
      amount: '555555', type: MovementType.debt,
      status: MovementStatus.approved, createdAt: DateTime(2026, 2, 9)),
  ];

  CustomerStatement statement({
    CurrencyCode currency = CurrencyCode.yer,
    MovementStatus? filter,
    String? merchantId = _merchantId,
    String customerId = 'c1',
  }) => CustomerStatementCalculator.calculate(
    customerId: customerId,
    merchantId: merchantId,
    currency: currency,
    from: DateTime(2026, 2, 1),
    to: DateTime(2026, 2, 28),
    relationships: relationships,
    movements: movements,
    filter: filter,
  );

  test('opening balance is historical approved debt minus payments', () {
    final v = statement();
    expect(v.openingBalance, Decimal.parse('35000'));
    expect(v.approvedDebts, Decimal.parse('90000.75'));
    expect(v.approvedPayments, Decimal.parse('25000'));
    expect(v.pendingAmount, Decimal.parse('7777'));
    expect(v.closingBalance, Decimal.parse('100000.75'));
    expect(v.rows.length, 4);
    expect(v.rows.first.id, 'period-payment');
    expect(v.rows.last.id, 'period-debt');
  });

  test('status tabs filter rows but cannot change financial totals', () {
    final all = statement();
    for (final status in MovementStatus.values) {
      final filtered = statement(filter: status);
      expect(filtered.rows.every((m) => m.status == status), true);
      expect(filtered.openingBalance, all.openingBalance);
      expect(filtered.approvedDebts, all.approvedDebts);
      expect(filtered.approvedPayments, all.approvedPayments);
      expect(filtered.pendingAmount, all.pendingAmount);
      expect(filtered.closingBalance, all.closingBalance);
      expect(filtered.allPeriodRows, hasLength(4));
    }
  });

  test('selected currency cannot include different currency movements', () {
    final sar = statement(currency: CurrencyCode.sar);
    expect(sar.openingBalance, Decimal.zero);
    expect(sar.approvedDebts, Decimal.parse('350'));
    expect(sar.approvedPayments, Decimal.zero);
    expect(sar.closingBalance, Decimal.parse('350'));
    expect(sar.rows.map((m) => m.id), ['sar-debt']);
    expect(statement(currency: CurrencyCode.usd).closingBalance,
      Decimal.zero);
  });

  test('missing merchant identity, pending relationship and wrong merchant are denied', () {
    for (final merchantId in <String?>[null, '', 'unknown-merchant']) {
      final result = statement(merchantId: merchantId);
      expect(result.hasApprovedRelationship, false);
      expect(result.rows, isEmpty);
      expect(result.closingBalance, Decimal.zero);
    }
    final pendingClient = statement(customerId: 'c2');
    expect(pendingClient.hasApprovedRelationship, false);
    expect(pendingClient.closingBalance, Decimal.zero);
  });

  test('negative closing balance is preserved as customer credit', () {
    final credit = _movement(
      id: 'credit', customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer, amount: '400000',
      type: MovementType.payment, status: MovementStatus.approved,
      createdAt: DateTime(2026, 2, 20),
    );
    final snapshot = CustomerStatementCalculator.calculate(
      customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer,
      from: DateTime(2026, 2, 1), to: DateTime(2026, 2, 28),
      relationships: relationships,
      movements: [...movements, credit],
    );
    expect(snapshot.closingBalance, Decimal.parse('-299999.25'));
  });

  test('rejects invalid backwards periods', () {
    expect(() => CustomerStatementCalculator.calculate(
      customerId: 'c1', merchantId: _merchantId,
      currency: CurrencyCode.yer,
      from: DateTime(2026, 3, 1), to: DateTime(2026, 2, 28),
      relationships: relationships, movements: movements,
    ), throwsArgumentError);
  });
}
