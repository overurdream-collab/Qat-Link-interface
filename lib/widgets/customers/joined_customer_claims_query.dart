import '../../models/app_models.dart';
import '../../models/merchant_pending_models.dart';

enum JoinedClaimStage {
  awaitingReview,
  acceptedAwaitingRelationship,
  acceptedAwaitingLedger,
  rejected,
}

class JoinedCustomerClaimRow {
  const JoinedCustomerClaimRow({
    required this.claim,
    required this.merchantName,
    required this.stage,
    required this.relationshipApproved,
  });

  final MerchantPendingDebt claim;
  final String merchantName;
  final JoinedClaimStage stage;
  final bool relationshipApproved;

  bool get canReview => stage == JoinedClaimStage.awaitingReview;
}

/// Presents every historical claim from verified contact-to-account matches.
/// An account appearing in the UI or having the same typed phone number is
/// NOT sufficient to discover merchant financial records.
///
/// Claim visibility is independent of relationship acceptance; the customer
/// must be allowed to review (and reject) prior merchant claims after signup.
/// Customer "accept" is an independent consent event, not ledger approval:
/// no recognized debt until the relationship + financial authorization have
/// both been verified and a corresponding MovementModel is posted on server.
abstract final class JoinedCustomerClaimsQuery {
  static List<JoinedCustomerClaimRow> forCustomer({
    required String? authenticatedCustomerId,
    required Iterable<CustomerModel> customers,
    required Iterable<MerchantPendingContact> contacts,
    required Iterable<MerchantPendingDebt> claims,
    required Iterable<VerifiedCustomerContactMatch> verifiedMatches,
    required Iterable<RelationshipModel> relationships,
    required Iterable<VerifiedCustomerClaimDecision> verifiedDecisions,
    required Map<String, String> verifiedMerchantNames,
  }) {
    if (authenticatedCustomerId == null ||
        authenticatedCustomerId.trim().isEmpty) return const [];

    final hasActiveAccount = customers.any((c) =>
        c.id == authenticatedCustomerId &&
        c.accountStatus == AccountStatus.active);
    if (!hasActiveAccount) return const [];

    final knownContactKeys = {
      for (final contact in contacts)
        '${contact.merchantId}|\u0001|${contact.id}',
    };

    // Fail closed if the server sends conflicting identities for a contact:
    // never expose the same merchant's private claims to multiple accounts.
    final verifiedOwners = <String, Set<String>>{};
    for (final match in verifiedMatches) {
      if (match.customerId.trim().isEmpty ||
          match.merchantId.trim().isEmpty ||
          match.contactId.trim().isEmpty) continue;
      final key = '${match.merchantId}|\u0001|${match.contactId}';
      if (knownContactKeys.contains(key)) {
        verifiedOwners.putIfAbsent(key, () => <String>{}).add(match.customerId);
      }
    }
    final matches = <String, String>{};
    for (final entry in verifiedOwners.entries) {
      if (entry.value.length == 1 &&
          entry.value.single == authenticatedCustomerId) {
        matches[entry.key] = authenticatedCustomerId;
      }
    }
    if (matches.isEmpty) return const [];

    final approvedMerchants = relationships.where((relationship) =>
      relationship.customerId == authenticatedCustomerId &&
      relationship.status == RelationshipStatus.approved)
      .map((relationship) => relationship.merchantId).toSet();

    // Server guarantees one decision per customer and merchant claim. If
    // duplicated in a stale payload, choose newest deterministically.
    final decisions = <String, VerifiedCustomerClaimDecision>{};
    for (final decision in verifiedDecisions) {
      if (decision.customerId != authenticatedCustomerId) continue;
      final key = '${decision.merchantId}|\u0001|${decision.claimId}';
      final old = decisions[key];
      if (old == null || decision.decidedAt.isAfter(old.decidedAt)) {
        decisions[key] = decision;
      }
    }

    final seen = <String>{};
    final result = <JoinedCustomerClaimRow>[];
    for (final claim in claims) {
      if (claim.merchantId.trim().isEmpty ||
          claim.contactId.trim().isEmpty) continue;
      final contactKey = '${claim.merchantId}|\u0001|${claim.contactId}';
      if (!matches.containsKey(contactKey)) continue;
      final claimKey = '${claim.merchantId}|\u0001|${claim.id}';
      if (!seen.add(claimKey)) continue;
      final review = decisions[claimKey];
      final linked = approvedMerchants.contains(claim.merchantId);
      final stage = review == null
          ? JoinedClaimStage.awaitingReview
          : review.decision == PreRegistrationClaimDecision.reject
              ? JoinedClaimStage.rejected
              : linked
                  ? JoinedClaimStage.acceptedAwaitingLedger
                  : JoinedClaimStage.acceptedAwaitingRelationship;
      result.add(JoinedCustomerClaimRow(
        claim: claim,
        merchantName: verifiedMerchantNames[claim.merchantId] ??
            'التاجر',
        stage: stage,
        relationshipApproved: linked,
      ));
    }
    result.sort((a, b) {
      final order = b.claim.createdAt.compareTo(a.claim.createdAt);
      return order != 0 ? order : a.claim.id.compareTo(b.claim.id);
    });
    return List.unmodifiable(result);
  }
}
