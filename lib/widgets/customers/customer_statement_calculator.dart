import 'package:decimal/decimal.dart';

import '../../models/app_models.dart';

/// One customer's statement in exactly ONE currency.
/// Status filters change visible rows, never the recognized balances.
class CustomerStatement {
  const CustomerStatement({
    required this.customerId,
    required this.currency,
    required this.from,
    required this.to,
    required this.filter,
    required this.openingBalance,
    required this.approvedDebts,
    required this.approvedPayments,
    required this.pendingAmount,
    required this.closingBalance,
    required this.rows,
    required this.allPeriodRows,
    required this.hasApprovedRelationship,
  });

  final String customerId;
  final CurrencyCode currency;
  final DateTime from;
  final DateTime to;
  final MovementStatus? filter;
  final Decimal openingBalance;
  final Decimal approvedDebts;
  final Decimal approvedPayments;
  final Decimal pendingAmount;
  final Decimal closingBalance;
  final List<MovementModel> rows;
  final List<MovementModel> allPeriodRows;
  final bool hasApprovedRelationship;

  int get visibleCount => rows.length;
}

/// Read-only calculations. No currency conversion, floating point, or writes.
abstract final class CustomerStatementCalculator {
  static CustomerStatement calculate({
    required String customerId,
    required String? merchantId,
    required CurrencyCode currency,
    required DateTime from,
    required DateTime to,
    required Iterable<RelationshipModel> relationships,
    required Iterable<MovementModel> movements,
    MovementStatus? filter,
  }) {
    final fromDay = DateTime(from.year, from.month, from.day);
    final toExclusive = DateTime(to.year, to.month, to.day + 1);
    if (!fromDay.isBefore(toExclusive)) {
      throw ArgumentError('Statement period is invalid.');
    }

    final approved = relationships.where((r) =>
        r.customerId == customerId &&
        (merchantId == null || r.merchantId == merchantId) &&
        r.status == RelationshipStatus.approved).toList();
    final relationIds = approved.map((r) => r.id).toSet();
    final eligible = movements.where((m) =>
        m.customerId == customerId &&
        (merchantId == null || m.merchantId == merchantId) &&
        m.currency == currency &&
        relationIds.contains(m.relationshipId));

    var opening = Decimal.zero;
    var debts = Decimal.zero;
    var paid = Decimal.zero;
    var pending = Decimal.zero;
    final inPeriod = <MovementModel>[];

    for (final m in eligible) {
      if (m.createdAt.isBefore(fromDay)) {
        if (m.status == MovementStatus.approved) {
          opening += m.type == MovementType.debt ? m.amount : -m.amount;
        }
        continue;
      }
      if (!m.createdAt.isBefore(toExclusive)) continue;
      inPeriod.add(m);
      switch (m.status) {
        case MovementStatus.approved:
          if (m.type == MovementType.debt) {
            debts += m.amount;
          } else {
            paid += m.amount;
          }
        case MovementStatus.pending:
          pending += m.amount;
        case MovementStatus.rejected:
          break;
      }
    }
    inPeriod.sort((a, b) {
      final chronological = b.createdAt.compareTo(a.createdAt);
      return chronological != 0
          ? chronological : b.id.compareTo(a.id);
    });
    return CustomerStatement(
      customerId: customerId,
      currency: currency,
      from: fromDay,
      to: DateTime(to.year, to.month, to.day),
      filter: filter,
      openingBalance: opening,
      approvedDebts: debts,
      approvedPayments: paid,
      pendingAmount: pending,
      closingBalance: opening + debts - paid,
      rows: List.unmodifiable(filter == null
          ? inPeriod : inPeriod.where((m) => m.status == filter)),
      allPeriodRows: List.unmodifiable(inPeriod),
      hasApprovedRelationship: approved.isNotEmpty,
    );
  }
}
