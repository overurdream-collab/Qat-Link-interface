import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/merchant_space/merchant_rating_policy.dart';
import 'package:qat_link/widgets/merchant_space/store_discovery_ranking.dart';

final now = DateTime(2026, 11, 15);
CustomerModel customer(String id) => CustomerModel(
  id: id, name: id, phone: '771234567',
  primaryCurrency: CurrencyCode.yer,
  createdAt: now, updatedAt: now,
);

RelationshipModel rel() => RelationshipModel(
  id: 'r1', merchantId: 'm1', customerId: 'c1',
  createdBy: 'm1', createdByRole: ParticipantRole.merchant,
  createdAt: now,
  approvals: [
    ApprovalRecord(actorId: 'm1', role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: now),
    ApprovalRecord(actorId: 'c1', role: ParticipantRole.customer,
      decision: ApprovalDecision.approved, decidedAt: now),
  ],
);

MovementModel m(MovementType type, MovementStatus status) => MovementModel(
  id: 'movement', relationshipId: 'r1',
  merchantId: 'm1', customerId: 'c1',
  amount: Decimal.parse('10'), currency: CurrencyCode.yer,
  type: type, createdBy: 'm1',
  createdByRole: ParticipantRole.merchant,
  createdAt: now,
  approvals: [
    ApprovalRecord(actorId: 'm1', role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: now),
    if (status != MovementStatus.pending)
      ApprovalRecord(actorId: 'c1', role: ParticipantRole.customer,
        decision: status == MovementStatus.approved
            ? ApprovalDecision.approved : ApprovalDecision.rejected,
        decidedAt: now),
  ],
);

MerchantReview review(String id, String customerId, int stars, {
  ReviewModeration moderation = ReviewModeration.published,
  DateTime? created,
}) => MerchantReview(
  id: id, merchantId: 'm1', customerId: customerId,
  verifiedPurchaseId: 'verified-$customerId', stars: stars,
  createdAt: created ?? now, moderation: moderation,
);

void main() {
  test('rating requires approved merchant-customer relationship and purchase', () {
    bool can(List<MovementModel> items, {
      List<RelationshipModel>? relations,
      String merchantId = 'm1',
    }) => MerchantReviewPolicy.canRateFromApprovedPurchase(
      merchantId: merchantId, customerId: 'c1',
      customers: [customer('c1')],
      relationships: relations ?? [rel()],
      movements: items,
    );
    expect(can([m(MovementType.debt, MovementStatus.approved)]), true);
    expect(can([m(MovementType.payment, MovementStatus.approved)]), false);
    expect(can([m(MovementType.debt, MovementStatus.pending)]), false);
    expect(can([m(MovementType.debt, MovementStatus.rejected)]), false);
    expect(can([m(MovementType.debt, MovementStatus.approved)],
      relations: []), false);
    expect(can([m(MovementType.debt, MovementStatus.approved)],
      merchantId: 'm2'), false);
  });

  test('one effective review per customer; hidden/pending cannot inflate rating', () {
    final reviews = [
      review('one', 'c1', 1, created: now.subtract(const Duration(days: 1))),
      review('updated', 'c1', 5, created: now),
      review('other', 'c2', 4),
      review('hidden', 'c3', 1, moderation: ReviewModeration.hidden),
      review('pending', 'c4', 5, moderation: ReviewModeration.pending),
    ];
    final result = MerchantReviewPolicy.summarize('m1', reviews);
    expect(result.publishedCount, 2);
    expect(result.average, 4.5);
    expect(result.eligibleForRanking, false);
    expect(result.rankingScore, null);
    expect(result.distribution[5], 1);
    expect(result.distribution[4], 1);
  });

  test('rankings require at least five trusted reviewers and bayesian correction', () {
    final reviews = [
      for (var i=0; i<5; i++) review('r$i', 'customer$i', 5),
    ];
    final summary = MerchantReviewPolicy.summarize('m1', reviews);
    expect(summary.eligibleForRanking, true);
    expect(summary.publishedCount, 5);
    expect(summary.average, 5);
    expect(summary.rankingScore, lessThan(5));
    expect(summary.rankingScore, greaterThan(3.5));
    expect(MerchantReviewPolicy.summarize('empty', reviews).average, null);
  });
  test('customer home most requested uses verified distinct buyers not fake volume', () {
    final fiveBuyers = [
      for (var i=0; i<5; i++)
        VerifiedFulfillment(
          merchantId: 'a', customerId: 'customer$i',
          orderId: 'o$i', fulfilledAt: now),
    ];
    final duplicateBuyer = [
      for (var i=0; i<50; i++)
        VerifiedFulfillment(
          merchantId: 'b', customerId: 'one',
          orderId: 'b$i', fulfilledAt: now),
    ];
    final stale = VerifiedFulfillment(
      merchantId: 'a', customerId: 'old',
      orderId: 'old', fulfilledAt: now.subtract(const Duration(days: 60)));
    final standings = StoreDiscoveryRanking.calculate(
      merchantIds: ['a','b','c'], reviews: const [],
      fulfillments: [...fiveBuyers, ...duplicateBuyer, stale],
      now: now,
    );
    final most = StoreDiscoveryRanking.mostRequested(standings);
    expect(most.map((r) => r.merchantId), ['a']);
    expect(most.single.uniqueBuyers, 5);
    expect(most.single.verifiedOrders, 5);
    expect(StoreDiscoveryRanking.bestRated(standings), isEmpty);
  });


}
