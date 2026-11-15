import 'package:decimal/decimal.dart';

import '../../models/app_models.dart';
import '../../models/merchant_pending_models.dart';

/// Three visually separate merchant balance categories for ONE currency.
/// A unilateral merchant claim is not the same thing as a pending MovementModel.
/// The recognized net may be negative (a customer credit).
class MerchantDebtStatusTotals {
  const MerchantDebtStatusTotals({
    required this.currency,
    required this.outsideApp,
    required this.awaitingCustomerApproval,
    required this.approvedNet,
    required this.outsideCount,
    required this.awaitingCount,
    required this.approvedCount,
  });

  final CurrencyCode currency;
  final Decimal outsideApp;
  final Decimal awaitingCustomerApproval;
  final Decimal approvedNet;
  final int outsideCount;
  final int awaitingCount;
  final int approvedCount;
}

/// Read-only status dashboard. It does not change any financial rights.
///
/// OUTSIDE APP = merchant-authored unverified claims, including records where
/// the customer's registration has NOT been verified yet.
/// AWAITING APPROVAL = authenticated two-party debt MovementModels still pending.
/// APPROVED = signed sum of approved debt/payment movements only.
///
/// The production server must atomically mark a claim as transferred once it
/// creates a corresponding pending MovementModel; pass its verified claim IDs
/// to avoid displaying the same claim in both stages. No phone matching here.
abstract final class MerchantDebtStatusQuery {
  static Map<CurrencyCode, MerchantDebtStatusTotals> summarize({
    required String? merchantId,
    required Iterable<MerchantPendingContact> contacts,
    required Iterable<MerchantPendingDebt> privateClaims,
    required Iterable<RelationshipModel> relationships,
    required Iterable<MovementModel> movements,
    Set<String> verifiedTransferredClaimIds = const {},
    Iterable<VerifiedCustomerContactMatch> verifiedCustomerMatches = const [],
    Iterable<VerifiedCustomerClaimDecision> verifiedClaimDecisions = const [],
  }) {
    if (merchantId == null || merchantId.trim().isEmpty) return const {};
    final contactIds = contacts
        .where((c) => c.merchantId == merchantId)
        .map((c) => c.id)
        .toSet();
    // Only server-verified account/contact links can transition a private
    // claim from "outside app" to "awaiting customer approval". A typed
    // phone number or merely registering an account is insufficient.
    final verifiedOwners = <String, Set<String>>{};
    for (final link in verifiedCustomerMatches) {
      if (link.merchantId != merchantId ||
          link.customerId.trim().isEmpty ||
          !contactIds.contains(link.contactId)) continue;
      verifiedOwners.putIfAbsent(
        link.contactId, () => <String>{}).add(link.customerId);
    }
    // Two conflicting verified accounts are not safe to transition; keep
    // claims in the outside-app bucket until backend identity resolution.
    final verifiedContacts = <String, String>{
      for (final entry in verifiedOwners.entries)
        if (entry.value.length == 1) entry.key: entry.value.single,
    };
    final rejectedClaims = <String>{};
    for (final decision in verifiedClaimDecisions) {
      if (decision.merchantId == merchantId &&
          decision.decision == PreRegistrationClaimDecision.reject &&
          decision.customerId.trim().isNotEmpty) {
        rejectedClaims.add('${decision.customerId}|\u0001|${decision.claimId}');
      }
    }
    final approvedRelationships = {
      for (final relationship in relationships)
        if (relationship.merchantId == merchantId &&
            relationship.status == RelationshipStatus.approved)
          relationship.id: relationship,
    };

    final totals = <CurrencyCode, MerchantDebtStatusTotals>{};
    for (final currency in CurrencyCode.values) {
      var outside = Decimal.zero;
      var awaiting = Decimal.zero;
      var approved = Decimal.zero;
      var outsideCount = 0;
      var awaitingCount = 0;
      var approvedCount = 0;

      for (final claim in privateClaims) {
        if (claim.merchantId != merchantId ||
            !contactIds.contains(claim.contactId) ||
            claim.currency != currency ||
            verifiedTransferredClaimIds.contains(claim.id)) continue;
        final verifiedCustomer = verifiedContacts[claim.contactId];
        if (verifiedCustomer == null) {
          outside += claim.amount;
          outsideCount++;
        } else if (!rejectedClaims.contains(
            '$verifiedCustomer|\u0001|${claim.id}')) {
          // Joined customer receives ALL historical claims; they remain
          // pending until reviewed. Accepted claims also remain pending
          // until the server safely posts a valid MovementModel.
          awaiting += claim.amount;
          awaitingCount++;
        }
      }

      for (final movement in movements) {
        if (movement.merchantId != merchantId ||
            movement.currency != currency) continue;
        final relationship = approvedRelationships[movement.relationshipId];
        if (relationship == null ||
            relationship.customerId != movement.customerId) continue;
        if (movement.status == MovementStatus.pending &&
            movement.type == MovementType.debt) {
          awaiting += movement.amount;
          awaitingCount++;
        } else if (movement.status == MovementStatus.approved) {
          approved += movement.type == MovementType.debt
              ? movement.amount : -movement.amount;
          approvedCount++;
        }
        // Pending payments do not count as pending debt; rejected entries
        // have zero effect on every category.
      }
      totals[currency] = MerchantDebtStatusTotals(
        currency: currency,
        outsideApp: outside,
        awaitingCustomerApproval: awaiting,
        approvedNet: approved,
        outsideCount: outsideCount,
        awaitingCount: awaitingCount,
        approvedCount: approvedCount,
      );
    }
    return Map.unmodifiable(totals);
  }
}
