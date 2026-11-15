import 'package:decimal/decimal.dart';

import '../../models/app_models.dart';
import 'booking_intake_policy.dart';

/// Debts from the financial ledger ONLY. Reservations do not create debts.
/// All figures below are per-currency; no currency conversion or mixing.
class DailyDebtSnapshot {
  const DailyDebtSnapshot({
    required this.approved,
    required this.pending,
    required this.approvedCount,
    required this.pendingCount,
  });

  final Map<CurrencyCode, Decimal> approved;
  final Map<CurrencyCode, Decimal> pending;
  final int approvedCount;
  final int pendingCount;
}

abstract final class DailyDebtQuery {
  static DailyDebtSnapshot calculate({
    required String? merchantId,
    required DateTime day,
    required Iterable<MovementModel> movements,
    required Iterable<RelationshipModel> relationships,
  }) {
    final approved = <CurrencyCode, Decimal>{};
    final pending = <CurrencyCode, Decimal>{};
    if (merchantId == null || merchantId.trim().isEmpty) {
      return const DailyDebtSnapshot(
        approved: {}, pending: {}, approvedCount: 0, pendingCount: 0);
    }
    final knownRelationships = relationships.where((r) =>
        r.merchantId == merchantId &&
        r.status == RelationshipStatus.approved).toList();
    final indexed = {for (final r in knownRelationships) r.id: r};
    var countApproved = 0, countPending = 0;
    bool sameDay(DateTime timestamp) {
      final local = BookingIntakePolicy.sanaaTime(timestamp);
      return local.year == day.year &&
          local.month == day.month && local.day == day.day;
    }

    for (final m in movements) {
      if (m.merchantId != merchantId ||
          m.type != MovementType.debt ||
          m.createdByRole != ParticipantRole.merchant ||
          m.createdBy != merchantId) continue;
      final relation = indexed[m.relationshipId];
      if (relation == null || relation.customerId != m.customerId) continue;
      if (m.status == MovementStatus.approved) {
        final approvals = m.approvals.where((record) =>
          record.actorId == m.customerId &&
          record.role == ParticipantRole.customer &&
          record.decision == ApprovalDecision.approved).toList();
        if (approvals.isEmpty || !sameDay(approvals.last.decidedAt)) continue;
        countApproved++;
        approved.update(m.currency, (sum) => sum + m.amount,
            ifAbsent: () => m.amount);
      } else if (m.status == MovementStatus.pending &&
          sameDay(m.createdAt)) {
        countPending++;
        pending.update(m.currency, (sum) => sum + m.amount,
            ifAbsent: () => m.amount);
      }
    }
    return DailyDebtSnapshot(
      approved: Map.unmodifiable(approved),
      pending: Map.unmodifiable(pending),
      approvedCount: countApproved,
      pendingCount: countPending,
    );
  }
}
