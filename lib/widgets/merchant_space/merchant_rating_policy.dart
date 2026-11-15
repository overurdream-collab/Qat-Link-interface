import '../../models/app_models.dart';

/// A review is earned by a customer-approved merchant-recorded debt, NOT\n/// a payment, booking, store visit or separate direct-sale transaction.
enum ReviewModeration { pending, published, hidden }

class MerchantReview {
  const MerchantReview({
    required this.id,
    required this.merchantId,
    required this.customerId,
    required this.verifiedPurchaseId,
    required this.stars,
    required this.createdAt,
    required this.moderation,
    this.comment = '',
  }) : assert(stars >= 1 && stars <= 5);

  final String id;
  final String merchantId;
  final String customerId;
  final String verifiedPurchaseId;
  final int stars;
  final String comment;
  final DateTime createdAt;
  final ReviewModeration moderation;
}

class MerchantRatingSummary {
  const MerchantRatingSummary({
    required this.publishedCount,
    required this.average,
    required this.rankingScore,
    required this.eligibleForRanking,
    required this.distribution,
  });

  final int publishedCount;
  final double? average;
  /// Bayesian adjusted average, only for stores with enough trusted reviews.
  final double? rankingScore;
  final bool eligibleForRanking;
  final Map<int, int> distribution;
}

abstract final class MerchantReviewPolicy {
  static const minimumTrustedReviews = 5;
  static const _priorCount = 10;
  static const _priorAverage = 3.5;

  /// An authenticated customer may rate a merchant after consenting to a\n  /// merchant-originated debt. The backend must verify that consent itself.\n  /// Pending/rejected movements, payments and bookings do not count.
  static bool canRateFromApprovedPurchase({
    required String merchantId,
    required String customerId,
    required Iterable<CustomerModel> customers,
    required Iterable<RelationshipModel> relationships,
    required Iterable<MovementModel> movements,
  }) {
    if (merchantId.isEmpty || customerId.isEmpty) return false;
    if (!customers.any((c) =>
        c.id == customerId && c.accountStatus == AccountStatus.active)) {
      return false;
    }
    final relationshipIds = relationships.where((r) =>
        r.customerId == customerId && r.merchantId == merchantId &&
        r.status == RelationshipStatus.approved).map((r) => r.id).toSet();
    if (relationshipIds.isEmpty) return false;
    return movements.any((m) =>
        m.merchantId == merchantId &&
        m.customerId == customerId &&
        relationshipIds.contains(m.relationshipId) &&
        m.type == MovementType.debt &&
        m.createdByRole == ParticipantRole.merchant &&
        m.createdBy == merchantId &&
        m.status == MovementStatus.approved &&
        m.approvals.any((record) =>
          record.role == ParticipantRole.customer &&
          record.actorId == customerId &&
          record.decision == ApprovalDecision.approved));
  }

  /// Ratings have one effective review per merchant/customer. A revised review
  /// REPLACES their previous review instead of boosting count. Only the
  /// published, verified set supplied by the backend is used here.
  static MerchantRatingSummary summarize(
      String merchantId, Iterable<MerchantReview> reviews) {
    final byCustomer = <String, MerchantReview>{};
    for (final r in reviews) {
      if (r.merchantId != merchantId ||
          r.moderation != ReviewModeration.published ||
          r.verifiedPurchaseId.trim().isEmpty) continue;
      final prior = byCustomer[r.customerId];
      if (prior == null || r.createdAt.isAfter(prior.createdAt)) {
        byCustomer[r.customerId] = r;
      }
    }
    final values = byCustomer.values.toList();
    final count = values.length;
    final sum = values.fold<int>(0, (n, r) => n + r.stars);
    return MerchantRatingSummary(
      publishedCount: count,
      average: count == 0 ? null : sum / count,
      rankingScore: count < minimumTrustedReviews ? null
          : (sum + _priorAverage * _priorCount) / (count + _priorCount),
      eligibleForRanking: count >= minimumTrustedReviews,
      distribution: Map.unmodifiable({
        for (var n = 1; n <= 5; n++)
          n: values.where((r) => r.stars == n).length,
      }),
    );
  }
}
