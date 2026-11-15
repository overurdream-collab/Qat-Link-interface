import '../../models/app_models.dart';
import 'merchant_rating_policy.dart';

class StoreDiscoveryStanding {
  const StoreDiscoveryStanding({
    required this.merchantId,
    required this.reviews,
    required this.approvedDebtMovements,
    required this.uniqueCustomers,
  });
  final String merchantId;
  final MerchantRatingSummary reviews;
  final int approvedDebtMovements;
  final int uniqueCustomers;
}

/// Public customer-home rankings rely on server-verified customer-approved
/// DEBTS, not "sales" or self-reported booking totals. The application has no
/// separate direct-sales transaction type.
abstract final class StoreDiscoveryRanking {
  static const minimumDistinctCustomers = 5;
  static const recentDays = 30;

  static List<StoreDiscoveryStanding> calculate({
    required Iterable<String> merchantIds,
    required Iterable<MerchantReview> reviews,
    required Iterable<MovementModel> movements,
    required Iterable<RelationshipModel> relationships,
    required Iterable<CustomerModel> customers,
    required DateTime now,
  }) {
    final start = now.toUtc().subtract(const Duration(days: recentDays));
    final end = now.toUtc();
    final activeCustomers = customers.where((customer) =>
        customer.accountStatus == AccountStatus.active)
        .map((customer) => customer.id).toSet();

    final output = <StoreDiscoveryStanding>[];
    for (final merchantId in merchantIds.toSet()) {
      final approvedRelations = {
        for (final relation in relationships)
          if (relation.merchantId == merchantId &&
              relation.status == RelationshipStatus.approved &&
              activeCustomers.contains(relation.customerId))
            relation.id: relation.customerId,
      };
      final qualifying = <String, MovementModel>{};
      for (final movement in movements) {
        if (movement.merchantId != merchantId ||
            movement.status != MovementStatus.approved ||
            movement.type != MovementType.debt ||
            movement.createdByRole != ParticipantRole.merchant ||
            movement.createdBy != merchantId ||
            approvedRelations[movement.relationshipId] !=
                movement.customerId) continue;

        final approvals = movement.approvals.where((record) =>
            record.actorId == movement.customerId &&
            record.role == ParticipantRole.customer &&
            record.decision == ApprovalDecision.approved).toList();
        if (approvals.isEmpty) continue;
        final approvedAt = approvals.last.decidedAt.toUtc();
        if (approvedAt.isBefore(start) || approvedAt.isAfter(end)) continue;
        qualifying.putIfAbsent(movement.id, () => movement);
      }

      output.add(StoreDiscoveryStanding(
        merchantId: merchantId,
        reviews: MerchantReviewPolicy.summarize(merchantId, reviews),
        approvedDebtMovements: qualifying.length,
        uniqueCustomers: qualifying.values.map((m) => m.customerId).toSet().length,
      ));
    }
    return List.unmodifiable(output);
  }

  static List<StoreDiscoveryStanding> bestRated(
      Iterable<StoreDiscoveryStanding> stores) {
    return [...stores.where((s) => s.reviews.eligibleForRanking)]
      ..sort((a, b) {
        final score = b.reviews.rankingScore!
            .compareTo(a.reviews.rankingScore!);
        return score != 0 ? score : a.merchantId.compareTo(b.merchantId);
      });
  }

  /// A diversity-of-customers metric, not a sales-volume or spend ranking.
  /// Subscription packages do not influence the organic ranking.
  static List<StoreDiscoveryStanding> mostRequested(
      Iterable<StoreDiscoveryStanding> stores) {
    return [...stores.where((s) =>
        s.uniqueCustomers >= minimumDistinctCustomers)]
      ..sort((a, b) {
        final clients = b.uniqueCustomers.compareTo(a.uniqueCustomers);
        if (clients != 0) return clients;
        final records = b.approvedDebtMovements.compareTo(a.approvedDebtMovements);
        return records != 0 ? records : a.merchantId.compareTo(b.merchantId);
      });
  }
}
