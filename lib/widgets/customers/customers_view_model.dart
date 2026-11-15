import 'package:decimal/decimal.dart';

import '../../models/app_models.dart';
import '../../services/movement_calculator.dart';
import '../movement/movement_view_model.dart';

enum CustomerListFilter { all, unpaid, pending, settled, unpaidAndPending }

enum CustomerSort { highestDebt, lowestDebt, newest, lastActivity }

/// An individual customer and currency. In ALL view, each currency is
/// displayed as a separate section rather than adding unlike currencies.
class CustomerCurrencyRow {
  const CustomerCurrencyRow({
    required this.customer,
    required this.currency,
    required this.balance,
    required this.pendingAmount,
    required this.pendingOperations,
    required this.lastActivity,
  });

  final CustomerModel customer;
  final CurrencyCode currency;
  final Decimal balance;
  final Decimal pendingAmount;
  final int pendingOperations;
  final DateTime lastActivity;
}

class CustomersViewModel {
  const CustomersViewModel._();

  static List<RelationshipModel> approvedRelationships(
    Iterable<RelationshipModel> relationships, {
    String? merchantId,
  }) => relationships
      .where((r) => r.status == RelationshipStatus.approved)
      .where((r) => merchantId == null || r.merchantId == merchantId)
      .toList(growable: false);

  static List<RelationshipModel> pendingRelationships(
    Iterable<RelationshipModel> relationships, {
    String? merchantId,
  }) => relationships
      .where((r) => r.status == RelationshipStatus.pending)
      .where((r) => merchantId == null || r.merchantId == merchantId)
      .toList(growable: false);

  static List<CustomerCurrencyRow> rows({
    required Iterable<CustomerModel> customers,
    required Iterable<RelationshipModel> relationships,
    required Iterable<MovementModel> movements,
    CurrencyCode? currency = CurrencyCode.yer,
    CustomerListFilter filter = CustomerListFilter.all,
    CustomerSort sort = CustomerSort.highestDebt,
    String search = '',
    String? merchantId,
  }) {
    final eligible = approvedRelationships(relationships,
        merchantId: merchantId);
    final ids = eligible.map((r) => r.customerId).toSet();
    final relIds = eligible.map((r) => r.id).toSet();
    // Always calculate from movements attached to approved relationships
    // only. Do not display unrelated or waiting-account money.
    final financial = movements
        .where((m) => relIds.contains(m.relationshipId))
        .toList(growable: false);
    final key = MovementQuery.normalizeSearch(search);
    final output = <CustomerCurrencyRow>[];
    for (final customer in customers) {
      if (!ids.contains(customer.id) ||
          customer.accountStatus != AccountStatus.active) {
        continue;
      }
      if (key.isNotEmpty &&
          !MovementQuery.normalizeSearch(customer.name).contains(key) &&
          !MovementQuery.normalizeSearch(customer.phone).contains(key)) {
        continue;
      }
      final clientMovements = financial
          .where((m) => m.customerId == customer.id)
          .toList(growable: false);
      final applicableCurrencies = <CurrencyCode>[
        if (currency != null)
          currency
        else
          for (final code in CurrencyCode.values)
            if (code == customer.primaryCurrency ||
                clientMovements.any((m) => m.currency == code))
              code,
      ];
      for (final code in applicableCurrencies) {
        final balance = MovementCalculator.customerBalance(
          clientMovements,
          customerId: customer.id,
          currency: code,
        );
        final pending = clientMovements.where((m) =>
            m.currency == code && m.status == MovementStatus.pending);
        final pendingCount = pending.length;
        final pendingAmount = pending.fold(
          Decimal.zero, (Decimal total, m) => total + m.amount);
        if (!_matches(filter, balance, pendingCount)) continue;
        var activity = customer.updatedAt;
        for (final movement in clientMovements.where((m) => m.currency == code)) {
          if (movement.createdAt.isAfter(activity)) {
            activity = movement.createdAt;
          }
        }
        output.add(CustomerCurrencyRow(
          customer: customer,
          currency: code,
          balance: balance,
          pendingAmount: pendingAmount,
          pendingOperations: pendingCount,
          lastActivity: activity,
        ));
      }
    }
    output.sort((a, b) {
      // ALL deliberately groups by currency so debt comparisons cannot
      // accidentally rank YER against USD.
      if (currency == null && a.currency != b.currency) {
        return a.currency.index.compareTo(b.currency.index);
      }
      final order = switch (sort) {
        CustomerSort.highestDebt => b.balance.compareTo(a.balance),
        CustomerSort.lowestDebt => a.balance.compareTo(b.balance),
        CustomerSort.newest =>
          b.customer.createdAt.compareTo(a.customer.createdAt),
        CustomerSort.lastActivity =>
          b.lastActivity.compareTo(a.lastActivity),
      };
      return order != 0 ? order : a.customer.name.compareTo(b.customer.name);
    });
    return output;
  }

  static bool _matches(
    CustomerListFilter filter, Decimal balance, int pending,
  ) => switch (filter) {
    CustomerListFilter.all => true,
    CustomerListFilter.unpaid => balance > Decimal.zero,
    CustomerListFilter.pending => pending > 0,
    CustomerListFilter.settled => balance == Decimal.zero && pending == 0,
    CustomerListFilter.unpaidAndPending =>
      balance > Decimal.zero && pending > 0,
  };

  static int distinctCustomers(Iterable<CustomerCurrencyRow> rows) =>
      rows.map((r) => r.customer.id).toSet().length;

  static int customersInDebt(Iterable<CustomerCurrencyRow> rows) => rows
      .where((r) => r.balance > Decimal.zero)
      .map((r) => r.customer.id)
      .toSet().length;

  static int pendingMovements(Iterable<CustomerCurrencyRow> rows) =>
      rows.fold<int>(0, (total, r) => total + r.pendingOperations);
}
