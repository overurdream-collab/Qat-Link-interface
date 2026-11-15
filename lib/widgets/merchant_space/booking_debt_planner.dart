import 'package:decimal/decimal.dart';

import '../../models/app_models.dart';
import 'merchant_space_models.dart';

/// Proposed requests for separate customer approvals, NOT ledger movements.
class BookingDebtRequestDraft {
  BookingDebtRequestDraft({
    required this.merchantId, required this.customerId,
    required this.relationshipId, required this.currency,
    required this.bookingIds, required this.amount,
  });
  final String merchantId;
  final String customerId;
  final String relationshipId;
  final CurrencyCode currency;
  final List<String> bookingIds;
  final Decimal amount;

  String get idempotencyKey {
    final sorted = [...bookingIds]..sort();
    return '$merchantId|$customerId|${currency.name}|${sorted.join(',')}';
  }
}

class BookingDebtPlan {
  const BookingDebtPlan({required this.requests, required this.skipped});
  final List<BookingDebtRequestDraft> requests;
  /// Booking ID -> explanation; no silently omitted booking.
  final Map<String, String> skipped;
  int get includedBookings =>
      requests.fold<int>(0, (n, r) => n + r.bookingIds.length);
}

class BookingDailyProposalAmounts {
  const BookingDailyProposalAmounts({
    required this.byCurrency, required this.missingPriceCount,
    required this.collectedCount,
    required this.paidByCurrency, required this.unpaidByCurrency,
  });
  final Map<CurrencyCode, Decimal> byCurrency;
  final Map<CurrencyCode, Decimal> paidByCurrency;
  final Map<CurrencyCode, Decimal> unpaidByCurrency;
  final int missingPriceCount;
  final int collectedCount;
}

/// A completed booking yields a PROPOSED amount only, not an approved debt.
/// These totals are draft proposals, NOT authoritative ledger figures.
abstract final class BookingProposalQuery {
  static BookingDailyProposalAmounts calculate(
      Iterable<ReservationDraft> bookings, DateTime day) {
    final byCurrency = <CurrencyCode, Decimal>{};
    final paid = <CurrencyCode, Decimal>{};
    final unpaid = <CurrencyCode, Decimal>{};
    var missing = 0;
    var collected = 0;
    for (final order in bookings) {
      if (order.status != ReservationStatus.collected ||
          order.day.year != day.year ||
          order.day.month != day.month ||
          order.day.day != day.day) continue;
      collected++;
      final total = order.proposedDebtAmount;
      if (total == null) { missing++; continue; }
      byCurrency.update(order.currency, (n) => n + total,
          ifAbsent: () => total);
      if (order.settlement == BookingSettlement.paid) {
        paid.update(order.currency, (n) => n + total,
            ifAbsent: () => total);
      } else if (order.settlement == BookingSettlement.unpaid) {
        unpaid.update(order.currency, (n) => n + total,
            ifAbsent: () => total);
      }
    }
    return BookingDailyProposalAmounts(
      byCurrency: Map.unmodifiable(byCurrency),
      paidByCurrency: Map.unmodifiable(paid),
      unpaidByCurrency: Map.unmodifiable(unpaid),
      missingPriceCount: missing, collectedCount: collected,
    );
  }
}

abstract final class BookingDebtPlanner {
  static BookingDebtPlan build({
    required String? merchantId,
    required Iterable<ReservationDraft> bookings,
    required Set<String> selectedIds,
    required Iterable<RelationshipModel> relationships,
    required Iterable<CustomerModel> customers,
    /// Backend authoritative set, required for live idempotent submission.
    Set<String> alreadySubmittedBookingIds = const {},
  }) {
    final skipped = <String, String>{};
    final requests = <String, BookingDebtRequestDraft>{};
    final selected = <String>{};
    final knownCustomers = {for (final c in customers) c.id: c};
    final approved = {
      if (merchantId != null && merchantId.trim().isNotEmpty)
        for (final rel in relationships)
          if (rel.merchantId == merchantId &&
              rel.status == RelationshipStatus.approved)
            rel.customerId: rel,
    };
    for (final b in bookings) {
      if (!selectedIds.contains(b.id)) continue;
      if (!selected.add(b.id)) {
        skipped[b.id] = 'الحجز مكرر في القائمة'; continue;
      }
      String? error;
      if (merchantId == null || merchantId.trim().isEmpty) {
        error = 'هوية التاجر الموثقة غير متوفرة';
      } else if (alreadySubmittedBookingIds.contains(b.id)) {
        error = 'هذا الحجز مرتبط بطلب دين سابق';
      } else if (b.status != ReservationStatus.collected) {
        error = 'لم يُستلم الطلب بعد';
      } else if (b.settlement != BookingSettlement.unpaid) {
        error = 'ليس مسجلاً كبيع غير مسدد';
      } else if (b.proposedDebtAmount == null || b.proposedDebtAmount! <= Decimal.zero) {
        error = 'السعر غير محدد';
      } else if (b.customerId == null ||
          knownCustomers[b.customerId]?.accountStatus != AccountStatus.active ||
          approved[b.customerId] == null) {
        error = 'العميل ليس مرتبطاً بالتاجر بعلاقة معتمدة';
      }
      if (error != null) { skipped[b.id] = error; continue; }
      final rel = approved[b.customerId]!;
      final key = '${b.customerId}|${b.currency.name}';
      final current = requests[key];
      if (current == null) {
        requests[key] = BookingDebtRequestDraft(
          merchantId: merchantId!, customerId: b.customerId!,
          relationshipId: rel.id, currency: b.currency,
          bookingIds: [b.id], amount: b.proposedDebtAmount!,
        );
      } else {
        requests[key] = BookingDebtRequestDraft(
          merchantId: current.merchantId, customerId: current.customerId,
          relationshipId: current.relationshipId, currency: current.currency,
          bookingIds: [...current.bookingIds, b.id],
          amount: current.amount + b.proposedDebtAmount!,
        );
      }
    }
    return BookingDebtPlan(
      requests: List.unmodifiable(requests.values),
      skipped: Map.unmodifiable(skipped),
    );
  }
}
