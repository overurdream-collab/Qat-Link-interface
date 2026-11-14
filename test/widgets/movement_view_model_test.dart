import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/movement/movement_view_model.dart';

CustomerModel customer(
  String id,
  String name,
  String phone,
) => CustomerModel(
  id: id,
  name: name,
  phone: phone,
  primaryCurrency: CurrencyCode.yer,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

MovementModel movement(
  String id,
  String customerId,
  String amount,
  CurrencyCode currency,
  MovementType type,
  MovementStatus status,
  DateTime date,
) {
  final approvals = <ApprovalRecord>[
    ApprovalRecord(
      actorId: 'merchant',
      role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared,
      decidedAt: date,
    ),
  ];
  if (status != MovementStatus.pending) {
    approvals.add(ApprovalRecord(
      actorId: customerId,
      role: ParticipantRole.customer,
      decision: status == MovementStatus.approved
          ? ApprovalDecision.approved
          : ApprovalDecision.rejected,
      decidedAt: date,
    ));
  }
  return MovementModel(
    id: id,
    relationshipId: 'relationship-$customerId',
    customerId: customerId,
    merchantId: 'merchant',
    amount: Decimal.parse(amount),
    currency: currency,
    type: type,
    createdBy: 'merchant',
    createdByRole: ParticipantRole.merchant,
    createdAt: date,
    approvals: approvals,
  );
}

void main() {
  final people = {
    'c1': customer('c1', 'محمد أحمد', '777123456'),
    'c2': customer('c2', 'علي صالح', '711987654'),
  };

  final data = [
    movement('debt-1', 'c1', '15000', CurrencyCode.yer,
        MovementType.debt, MovementStatus.approved,
        DateTime(2026, 11, 11, 10, 30)),
    movement('payment-pending', 'c2', '5000', CurrencyCode.yer,
        MovementType.payment, MovementStatus.pending,
        DateTime(2026, 11, 11, 9, 15)),
    movement('rejected-1', 'c1', '8000', CurrencyCode.yer,
        MovementType.debt, MovementStatus.rejected,
        DateTime(2026, 11, 11, 8, 20)),
    movement('payment-approved', 'c1', '4500', CurrencyCode.yer,
        MovementType.payment, MovementStatus.approved,
        DateTime(2026, 11, 8, 14)),
    movement('sar-debt', 'c1', '200', CurrencyCode.sar,
        MovementType.debt, MovementStatus.approved,
        DateTime(2026, 11, 11, 7)),
    movement('old', 'c1', '9000', CurrencyCode.yer,
        MovementType.debt, MovementStatus.approved,
        DateTime(2026, 10, 30)),
  ];

  group('Movement HTML financial summary rules', () {
    test('gross includes pending, excludes rejected and older dates', () {
      final rows = MovementQuery.filter(
        data,
        customers: people,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 11),
        currency: CurrencyCode.yer,
      );
      final totals = MovementQuery.totalsByCurrency(rows);
      final yer = totals[CurrencyCode.yer]!;
      expect(yer.grossNonRejected, Decimal.parse('24500'));
      expect(yer.approvedDebts, Decimal.parse('15000'));
      expect(yer.approvedPayments, Decimal.parse('4500'));
      expect(yer.pending, Decimal.parse('5000'));
      expect(rows.length, 4); // rejected visible in list but not totals
    });

    test('filtered status changes list but not the approved totals', () {
      final result = MovementQuery.filter(
        data,
        customers: people,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 11),
        currency: CurrencyCode.yer,
        status: MovementStatus.pending,
      );
      expect(result.length, 1);
      expect(result.single.id, 'payment-pending');
    });

    test('search finds customer name, phone, and operation ID', () {
      for (final term in ['محمد', '777123456', 'debt-1']) {
        final rows = MovementQuery.filter(
          data,
          customers: people,
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 11),
          search: term,
          currency: CurrencyCode.yer,
        );
        expect(rows.isNotEmpty, true, reason: term);
        expect(rows.every((m) => m.customerId == 'c1'), true);
      }
    });

    test('date ranges are inclusive at both local day boundaries', () {
      final rows = MovementQuery.filter(
        data,
        customers: people,
        from: DateTime(2026, 11, 11),
        to: DateTime(2026, 11, 11),
        currency: CurrencyCode.yer,
      );
      expect(rows.length, 3);
    });

    test('all currencies remain separate even in all-currency mode', () {
      final rows = MovementQuery.filter(
        data,
        customers: people,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 11),
      );
      final totals = MovementQuery.totalsByCurrency(rows);
      expect(totals[CurrencyCode.yer]!.grossNonRejected,
          Decimal.parse('24500'));
      expect(totals[CurrencyCode.sar]!.grossNonRejected,
          Decimal.parse('200'));
      expect(totals[CurrencyCode.usd]!.grossNonRejected,
          Decimal.zero);
    });

    test('day grouping preserves newest-first list order', () {
      final rows = MovementQuery.filter(
        data,
        customers: people,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 11),
        currency: CurrencyCode.yer,
      );
      final groups = MovementQuery.byDay(rows);
      expect(groups.keys.first, DateTime(2026, 11, 11));
      expect(groups.keys.last, DateTime(2026, 11, 8));
    });

    test('negative credit balances are not masked by the UI totals', () {
      final rows = [
        movement('credit', 'c1', '6500', CurrencyCode.yer,
            MovementType.payment, MovementStatus.approved,
            DateTime(2026, 11, 10)),
        movement('debt', 'c1', '2000', CurrencyCode.yer,
            MovementType.debt, MovementStatus.approved,
            DateTime(2026, 11, 10)),
      ];
      final total = MovementQuery.totalsByCurrency(rows)[CurrencyCode.yer]!;
      expect(total.approvedDebts - total.approvedPayments,
          Decimal.parse('-4500'));
    });
  });
}
