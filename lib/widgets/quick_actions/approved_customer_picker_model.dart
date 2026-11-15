import '../../models/app_models.dart';
import '../movement/movement_view_model.dart';

/// An approved merchant↔customer pair. A customer profile alone is insufficient
/// to enable a financial entry. Caller must provide the merchant identity from
/// a trusted session in production.
class ApprovedCustomerOption {
  const ApprovedCustomerOption({
    required this.customer,
    required this.relationship,
  });

  final CustomerModel customer;
  final RelationshipModel relationship;
}

abstract final class ApprovedCustomerPickerModel {
  static List<ApprovedCustomerOption> available({
    required Iterable<CustomerModel> customers,
    required Iterable<RelationshipModel> relationships,
    required String? merchantId,
    String search = '',
  }) {
    // Fail closed in the absence of a verified merchant context.
    if (merchantId == null || merchantId.trim().isEmpty) return const [];

    final byId = <String, CustomerModel>{
      for (final customer in customers) customer.id: customer,
    };
    final query = MovementQuery.normalizeSearch(search);
    final options = <ApprovedCustomerOption>[];
    final seen = <String>{};
    for (final relationship in relationships) {
      if (relationship.merchantId != merchantId ||
          relationship.status != RelationshipStatus.approved) {
        continue;
      }
      final customer = byId[relationship.customerId];
      if (customer == null || customer.accountStatus != AccountStatus.active) {
        continue;
      }
      if (!seen.add(customer.id)) continue;
      if (query.isNotEmpty &&
          !MovementQuery.normalizeSearch(customer.name).contains(query) &&
          !MovementQuery.normalizeSearch(customer.phone).contains(query)) {
        continue;
      }
      options.add(ApprovedCustomerOption(
        customer: customer, relationship: relationship));
    }
    options.sort((a, b) => a.customer.name.compareTo(b.customer.name));
    return options;
  }

  /// Confirm the selected relationship is still approved at submission time.
  /// The server MUST re-verify identities/permissions for actual writes.
  static bool isStillEligible({
    required ApprovedCustomerOption? selection,
    required Iterable<CustomerModel> customers,
    required Iterable<RelationshipModel> relationships,
    required String? merchantId,
  }) {
    if (selection == null || merchantId == null) return false;
    return available(
      customers: customers,
      relationships: relationships,
      merchantId: merchantId,
    ).any((item) =>
        item.customer.id == selection.customer.id &&
        item.relationship.id == selection.relationship.id);
  }
}
