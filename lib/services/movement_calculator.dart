import '../models/app_models.dart';

/// Pure accounting calculations for movements approved by BOTH parties.
///
/// Every result is scoped to one currency. This service intentionally does
/// not convert currencies or store a customer balance.
abstract final class MovementCalculator {
  static double customerBalance(
    Iterable<MovementModel> movements, {
    required String customerId,
    required CurrencyCode currency,
  }) {
    return movements
        .where(
          (movement) =>
              movement.customerId == customerId &&
              movement.currency == currency &&
              movement.approval.isApproved,
        )
        .fold<double>(0, (balance, movement) {
          return balance + _signedAmount(movement);
        });
  }

  static double approvedDebts(
    Iterable<MovementModel> movements, {
    String? customerId,
    required CurrencyCode currency,
  }) {
    return _total(
      movements,
      customerId: customerId,
      currency: currency,
      type: MovementType.debt,
      approvalStatus: ApprovalStatus.approved,
    );
  }

  static double approvedPayments(
    Iterable<MovementModel> movements, {
    String? customerId,
    required CurrencyCode currency,
  }) {
    return _total(
      movements,
      customerId: customerId,
      currency: currency,
      type: MovementType.payment,
      approvalStatus: ApprovalStatus.approved,
    );
  }

  static double pendingTotal(
    Iterable<MovementModel> movements, {
    String? customerId,
    required CurrencyCode currency,
  }) {
    return movements
        .where(
          (movement) =>
              movement.currency == currency &&
              (customerId == null || movement.customerId == customerId) &&
              movement.approval.isPending,
        )
        .fold<double>(0, (total, movement) => total + movement.amount);
  }

  static Map<CurrencyCode, double> balancesByCurrency(
    Iterable<MovementModel> movements, {
    required String customerId,
  }) {
    return {
      for (final currency in CurrencyCode.values)
        currency: customerBalance(
          movements,
          customerId: customerId,
          currency: currency,
        ),
    };
  }

  static double _total(
    Iterable<MovementModel> movements, {
    required String? customerId,
    required CurrencyCode currency,
    required MovementType type,
    required ApprovalStatus approvalStatus,
  }) {
    return movements
        .where(
          (movement) =>
              movement.currency == currency &&
              (customerId == null || movement.customerId == customerId) &&
              movement.type == type &&
              movement.approval.status == approvalStatus,
        )
        .fold<double>(0, (total, movement) => total + movement.amount);
  }

  static double _signedAmount(MovementModel movement) {
    return switch (movement.type) {
      MovementType.debt => movement.amount,
      MovementType.payment => -movement.amount,
    };
  }
}
