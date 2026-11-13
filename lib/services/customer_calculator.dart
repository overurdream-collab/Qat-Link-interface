import 'package:decimal/decimal.dart';

import '../models/app_models.dart';
import 'movement_calculator.dart';

abstract final class CustomerCalculator {
  static Map<CurrencyCode, Decimal> balances(
    Iterable<MovementModel> movements, {
    required String customerId,
  }) =>
      MovementCalculator.balancesByCurrency(movements, customerId: customerId);

  static bool hasOutstandingBalance(
    Iterable<MovementModel> movements, {
    required String customerId,
  }) =>
      balances(movements, customerId: customerId)
          .values
          .any((amount) => amount > Decimal.zero);

  static bool isSettled(
    Iterable<MovementModel> movements, {
    required String customerId,
  }) =>
      balances(movements, customerId: customerId)
          .values
          .every((amount) => amount == Decimal.zero);
}
