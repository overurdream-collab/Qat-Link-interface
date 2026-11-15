import 'package:decimal/decimal.dart';

import '../../models/app_models.dart';
import '../../services/movement_calculator.dart';

/// Local UI draft only. Reservations are operational requests, never debt
/// movements, and cannot affect approved balances.
enum ReservationStatus {
  awaitingConfirmation,
  confirmed,
  preparing,
  ready,
  collected,
  cancelled,
}

extension ReservationStatusLabels on ReservationStatus {
  String get label => switch (this) {
    ReservationStatus.awaitingConfirmation => 'بانتظار التأكيد',
    ReservationStatus.confirmed => 'مؤكد',
    ReservationStatus.preparing => 'قيد التجهيز',
    ReservationStatus.ready => 'جاهز للاستلام',
    ReservationStatus.collected => 'تم الاستلام',
    ReservationStatus.cancelled => 'ملغي',
  };
}

enum BookingSettlement { unknown, paid, unpaid }

class ReservationDraft {
  ReservationDraft({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.item,
    required this.bundles,
    required this.day,
    required this.pickupTime,
    required this.createdAt,
    this.note = '',
    this.status = ReservationStatus.awaitingConfirmation,
    this.customerId,
    this.unitPrice,
    this.currency = CurrencyCode.yer,
    this.settlement = BookingSettlement.unknown,
  }) {
    if (bundles <= 0) throw ArgumentError('Bundles must be positive');
    if (unitPrice != null && unitPrice! <= Decimal.zero) {
      throw ArgumentError('Unit price must be positive');
    }
  }

  final String id;
  final String customerName;
  final String phone;
  final String item;
  final int bundles;
  final DateTime day;
  final String pickupTime;
  final DateTime createdAt;
  final String note;
  final ReservationStatus status;
  /// Verified linked account ID, not a text name/phone guess.
  final String? customerId;
  /// Unit price is optional; missing price must not become a zero-value financial entry.
  final Decimal? unitPrice;
  final CurrencyCode currency;
  final BookingSettlement settlement;

  Decimal? get proposedDebtAmount => unitPrice == null
      ? null : unitPrice! * Decimal.fromInt(bundles);

  ReservationDraft withStatus(ReservationStatus value) => ReservationDraft(
    id: id, customerName: customerName, phone: phone,
    item: item, bundles: bundles, day: day,
    pickupTime: pickupTime, createdAt: createdAt,
    note: note, status: value, customerId: customerId,
    unitPrice: unitPrice, currency: currency, settlement: settlement,
  );
}

class ReservationDailySummary {
  const ReservationDailySummary({
    required this.orders,
    required this.activeCount,
    required this.totalBundles,
    required this.readyCount,
    required this.bundlesByItem,
  });

  final List<ReservationDraft> orders;
  final int activeCount;
  final int totalBundles;
  final int readyCount;
  final Map<String, int> bundlesByItem;
}

abstract final class ReservationsQuery {
  static ReservationDailySummary forDay(
    Iterable<ReservationDraft> input,
    DateTime day,
  ) {
    final matches = input.where((r) =>
      r.day.year == day.year &&
      r.day.month == day.month &&
      r.day.day == day.day).toList();
    matches.sort((a,b) {
      final time = a.pickupTime.compareTo(b.pickupTime);
      return time != 0 ? time : a.createdAt.compareTo(b.createdAt);
    });
    final active = matches.where((r) => r.status != ReservationStatus.cancelled
        && r.status != ReservationStatus.collected).toList();
    final byItem = <String, int>{};
    for (final item in active) {
      byItem.update(item.item, (sum) => sum + item.bundles,
          ifAbsent: () => item.bundles);
    }
    return ReservationDailySummary(
      orders: List.unmodifiable(matches),
      activeCount: active.length,
      totalBundles: active.fold<int>(0, (sum,r) => sum + r.bundles),
      readyCount: active.where((r) => r.status == ReservationStatus.ready).length,
      bundlesByItem: Map.unmodifiable(byItem),
    );
  }
}

enum BroadcastAudience { all, pending, unpaid }

extension BroadcastAudienceLabel on BroadcastAudience {
  String get label => switch (this) {
    BroadcastAudience.all => 'كل العملاء',
    BroadcastAudience.pending => 'لديهم عمليات عالقة',
    BroadcastAudience.unpaid => 'غير المسددين',
  };
}

/// Marketing segmentation by customer IDs only, never a sum across currencies.
/// Merchant ID is supplied only from an authenticated context in production.
abstract final class MerchantAudienceQuery {
  static List<CustomerModel> eligible({
    required String? merchantId,
    required Iterable<CustomerModel> customers,
    required Iterable<RelationshipModel> relationships,
    required Iterable<MovementModel> movements,
    required BroadcastAudience audience,
  }) {
    if (merchantId == null || merchantId.trim().isEmpty) return const [];
    final approved = relationships.where((r) =>
      r.merchantId == merchantId &&
      r.status == RelationshipStatus.approved).toList();
    final ids = approved.map((r) => r.customerId).toSet();
    final relationIds = approved.map((r) => r.id).toSet();
    final trustedMovements = movements.where((m) =>
      m.merchantId == merchantId &&
      ids.contains(m.customerId) &&
      relationIds.contains(m.relationshipId)).toList();
    final selected = customers.where((customer) {
      if (customer.accountStatus != AccountStatus.active ||
          !ids.contains(customer.id)) return false;
      if (audience == BroadcastAudience.all) return true;
      if (audience == BroadcastAudience.pending) {
        return trustedMovements.any((m) =>
          m.customerId == customer.id &&
          m.status == MovementStatus.pending);
      }
      return CurrencyCode.values.any((currency) =>
        MovementCalculator.customerBalance(
          trustedMovements, customerId: customer.id,
          currency: currency) > Decimal.zero);
    }).toList();
    selected.sort((a,b) => a.name.compareTo(b.name));
    return List.unmodifiable(selected);
  }
}
