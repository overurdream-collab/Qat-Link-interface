import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/services/movement_calculator.dart';

void main() {
  final time = DateTime.utc(2026);
  final approved = [
    ApprovalRecord(actorId: 'm1', role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: time),
    ApprovalRecord(actorId: 'c1', role: ParticipantRole.customer,
      decision: ApprovalDecision.approved, decidedAt: time),
  ];
  MovementModel make(String id, String amount, MovementType type,
      {CurrencyCode currency = CurrencyCode.yer, List<ApprovalRecord>? approvals}) =>
    MovementModel(id: id, relationshipId: 'r1', customerId: 'c1',
      merchantId: 'm1', amount: Decimal.parse(amount), currency: currency,
      type: type, createdBy: 'm1', createdByRole: ParticipantRole.merchant,
      createdAt: time, approvals: approvals ?? approved);

  test('exact decimal balance excludes pending and rejected records', () {
    final rows = [
      make('d', '10.10', MovementType.debt),
      make('p', '0.20', MovementType.payment),
      make('pending', '100', MovementType.debt, approvals: [approved.first]),
      make('rejected', '500', MovementType.debt, approvals: [
        ...approved,
        ApprovalRecord(actorId: 'c1', role: ParticipantRole.customer,
          decision: ApprovalDecision.rejected, decidedAt: time),
      ]),
    ];
    expect(MovementCalculator.customerBalance(rows, customerId: 'c1',
      currency: CurrencyCode.yer), Decimal.parse('9.90'));
  });

  test('currencies are calculated independently', () {
    final rows = [
      make('yer', '10', MovementType.debt),
      make('sar', '2.50', MovementType.debt, currency: CurrencyCode.sar),
    ];
    expect(MovementCalculator.customerBalance(rows, customerId: 'c1',
      currency: CurrencyCode.yer), Decimal.parse('10'));
    expect(MovementCalculator.customerBalance(rows, customerId: 'c1',
      currency: CurrencyCode.sar), Decimal.parse('2.50'));
  });

  test('overpayment creates a negative balance', () {
    final rows = [
      make('d', '2', MovementType.debt),
      make('p', '3.25', MovementType.payment),
    ];
    expect(MovementCalculator.customerBalance(rows, customerId: 'c1',
      currency: CurrencyCode.yer), Decimal.parse('-1.25'));
  });
}
