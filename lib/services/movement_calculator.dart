import 'package:decimal/decimal.dart';

import '../models/app_models.dart';

/// Pure financial calculations. Only fully approved movements are counted.
abstract final class MovementCalculator {
  static Decimal customerBalance(
    Iterable<MovementModel> movements, {
    required String customerId,
    required CurrencyCode currency,
  }) {
    return movements
        .where((m) =>
            m.customerId == customerId &&
            m.currency == currency &&
            m.status == MovementStatus.approved)
        .fold(Decimal.zero, (sum, m) => sum + _signed(m));
  }

  static Decimal approvedDebts(
    Iterable<MovementModel> movements, {
    String? customerId,
    required CurrencyCode currency,
  }) =>
      _total(movements, customerId, currency, MovementType.debt,
          MovementStatus.approved);

  static Decimal approvedPayments(
    Iterable<MovementModel> movements, {
    String? customerId,
    required CurrencyCode currency,
  }) =>
      _total(movements, customerId, currency, MovementType.payment,
          MovementStatus.approved);

  static Decimal pendingTotal(
    Iterable<MovementModel> movements, {
    String? customerId,
    required CurrencyCode currency,
  }) =>
      movements
          .where((m) =>
              m.currency == currency &&
              (customerId == null || m.customerId == customerId) &&
              m.status == MovementStatus.pending)
          .fold(Decimal.zero, (sum, m) => sum + m.amount);

  static Map<CurrencyCode, Decimal> balancesByCurrency(
    Iterable<MovementModel> movements, {
    required String customerId,
  }) =>
      {
        for (final currency in CurrencyCode.values)
          currency: customerBalance(
            movements,
            customerId: customerId,
            currency: currency,
          ),
      };

  static Decimal _total(
    Iterable<MovementModel> movements,
    String? customerId,
    CurrencyCode currency,
    MovementType type,
    MovementStatus status,
  ) =>
      movements
          .where((m) =>
              m.currency == currency &&
              (customerId == null || m.customerId == customerId) &&
              m.type == type &&
              m.status == status)
          .fold(Decimal.zero, (sum, m) => sum + m.amount);

  static Decimal _signed(MovementModel movement) =>
      movement.type == MovementType.debt
          ? movement.amount
          : -movement.amount;
}
