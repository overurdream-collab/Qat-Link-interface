import 'merchant_rating_policy.dart';

/// Verified server event. Local bookings and unconfirmed customer orders MUST
/// NOT be used for public "most requested" rankings.
class VerifiedFulfillment {
  const VerifiedFulfillment({
    required this.merchantId,
    required this.customerId,
    required this.orderId,
    required this.fulfilledAt,
  });

  final String merchantId;
  final String customerId;
  final String orderId;
  final DateTime fulfilledAt;
}

class StoreDiscoveryStanding {
  const StoreDiscoveryStanding({
    required this.merchantId,
    required this.reviews,
    required this.verifiedOrders,
    required this.uniqueBuyers,
  });
  final String merchantId;
  final MerchantRatingSummary reviews;
  final int verifiedOrders;
  final int uniqueBuyers;
}

abstract final class StoreDiscoveryRanking {
  static const minimumDistinctBuyers = 5;
  static const recentDays = 30;

  static List<StoreDiscoveryStanding> calculate({
    required Iterable<String> merchantIds,
    required Iterable<MerchantReview> reviews,
    required Iterable<VerifiedFulfillment> fulfillments,
    required DateTime now,
  }) {
    final start = now.subtract(const Duration(days: recentDays));
    final output = <StoreDiscoveryStanding>[];
    for (final id in merchantIds.toSet()) {
      final orders = <String, VerifiedFulfillment>{};
      for (final item in fulfillments) {
        if (item.merchantId != id ||
            item.customerId.trim().isEmpty ||
            item.orderId.trim().isEmpty ||
            item.fulfilledAt.isBefore(start) ||
            item.fulfilledAt.isAfter(now)) continue;
        orders.putIfAbsent(item.orderId, () => item);
      }
      output.add(StoreDiscoveryStanding(
        merchantId: id,
        reviews: MerchantReviewPolicy.summarize(id, reviews),
        verifiedOrders: orders.length,
        uniqueBuyers: orders.values.map((o) => o.customerId).toSet().length,
      ));
    }
    return List.unmodifiable(output);
  }

  /// Customer Home: top-rated among qualified stores only.
  static List<StoreDiscoveryStanding> bestRated(
      Iterable<StoreDiscoveryStanding> stores) {
    return [...stores.where((s) => s.reviews.eligibleForRanking)]
      ..sort((a,b) {
        final byScore = b.reviews.rankingScore!
            .compareTo(a.reviews.rankingScore!);
        return byScore != 0 ? byScore
            : a.merchantId.compareTo(b.merchantId);
      });
  }

  /// Customer Home: popular by distinct verified buyers in recent period,
  /// then completed order count as a tie-breaker; never by ad package.
  static List<StoreDiscoveryStanding> mostRequested(
      Iterable<StoreDiscoveryStanding> stores) {
    return [...stores.where((s) => s.uniqueBuyers >= minimumDistinctBuyers)]
      ..sort((a,b) {
        final byBuyers = b.uniqueBuyers.compareTo(a.uniqueBuyers);
        if (byBuyers != 0) return byBuyers;
        final byOrders = b.verifiedOrders.compareTo(a.verifiedOrders);
        return byOrders != 0 ? byOrders
            : a.merchantId.compareTo(b.merchantId);
      });
  }
}
