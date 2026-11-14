import 'package:decimal/decimal.dart';

import '../../models/app_models.dart';

/// UI-only query and reporting logic. This does not mutate the ledger.
class MovementQuery {
  const MovementQuery._();

  static List<MovementModel> filter(
    Iterable<MovementModel> source, {
    required Map<String, CustomerModel> customers,
    required DateTime from,
    required DateTime to,
    CurrencyCode? currency,
    MovementStatus? status,
    String search = '',
  }) {
    final lowerBound = DateTime(from.year, from.month, from.day);
    final upperExclusive = DateTime(to.year, to.month, to.day + 1);
    final key = normalizeSearch(search);
    final filtered = source.where((movement) {
      if (currency != null && movement.currency != currency) return false;
      if (status != null && movement.status != status) return false;
      if (movement.createdAt.isBefore(lowerBound) ||
          !movement.createdAt.isBefore(upperExclusive)) {
        return false;
      }
      if (key.isEmpty) return true;
      final customer = customers[movement.customerId];
      return [
        movement.id,
        movement.description ?? '',
        customer?.name ?? '',
        customer?.phone ?? '',
      ].any((value) => normalizeSearch(value).contains(key));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  static String normalizeSearch(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[\s\-]'), '');

  /// Deterministic day grouping; caller supplies newest-first movements.
  static Map<DateTime, List<MovementModel>> byDay(
    Iterable<MovementModel> movements,
  ) {
    final output = <DateTime, List<MovementModel>>{};
    for (final movement in movements) {
      final day = DateTime(
        movement.createdAt.year,
        movement.createdAt.month,
        movement.createdAt.day,
      );
      output.putIfAbsent(day, () => <MovementModel>[]).add(movement);
    }
    return output;
  }

  /// Never sum amounts from different currencies into one metric.
  static Map<CurrencyCode, MovementPeriodTotals> totalsByCurrency(
    Iterable<MovementModel> movements,
  ) {
    final output = <CurrencyCode, MovementPeriodTotals>{};
    for (final currency in CurrencyCode.values) {
      output[currency] = MovementPeriodTotals.fromMovements(
        movements.where((m) => m.currency == currency),
      );
    }
    return output;
  }
}

/// Gross volume is NOT approved debt balance: it is approved+pending volume
/// for the selected period and currency, including BOTH debt and payment.
/// Rejected movements contribute zero to all totals.
class MovementPeriodTotals {
  const MovementPeriodTotals({
    required this.grossNonRejected,
    required this.approvedDebts,
    required this.pending,
    required this.approvedPayments,
    required this.includedCount,
  });

  final Decimal grossNonRejected;
  final Decimal approvedDebts;
  final Decimal pending;
  final Decimal approvedPayments;
  final int includedCount;

  static MovementPeriodTotals fromMovements(
    Iterable<MovementModel> movements,
  ) {
    var gross = Decimal.zero;
    var debts = Decimal.zero;
    var pending = Decimal.zero;
    var payments = Decimal.zero;
    var count = 0;
    for (final movement in movements) {
      switch (movement.status) {
        case MovementStatus.rejected:
          break;
        case MovementStatus.pending:
          gross += movement.amount;
          pending += movement.amount;
          count++;
        case MovementStatus.approved:
          gross += movement.amount;
          count++;
          if (movement.type == MovementType.debt) {
            debts += movement.amount;
          } else {
            payments += movement.amount;
          }
      }
    }
    return MovementPeriodTotals(
      grossNonRejected: gross,
      approvedDebts: debts,
      pending: pending,
      approvedPayments: payments,
      includedCount: count,
    );
  }
}
