import '../../models/app_models.dart';
import 'booking_intake_policy.dart';
import 'merchant_space_models.dart';

/// The merchant selects the audience; this is NOT permission to notify it.
enum NightReminderAudience {
  yesterdayConfirmed,
  previousSevenDays,
  allApproved,
  favorites,
}

extension NightReminderAudienceLabel on NightReminderAudience {
  String get label => switch (this) {
    NightReminderAudience.yesterdayConfirmed => 'حجوزات الأمس المؤكدة',
    NightReminderAudience.previousSevenDays => 'عملاء آخر 7 أيام',
    NightReminderAudience.allApproved => 'كل العملاء',
    NightReminderAudience.favorites => 'العملاء المفضلون',
  };
}

/// Merchant entitlements are checked by the backend at scheduling/send time.
/// Feature names are fixed; packages/prices/quotas are intentionally UNSET.
enum MerchantSubscriptionFeature {
  nightlyBookingReminders,
  customerAudienceSegments,
  reminderOpenAnalytics,
  oneTapConfirmedBookings,
}

class NightReminderCampaignDraft {
  const NightReminderCampaignDraft({
    required this.id,
    required this.merchantId,
    required this.day,
    required this.audience,
    this.offeredItem,
    this.pickupTime,
  });

  final String id;
  final String merchantId;
  final DateTime day;
  final NightReminderAudience audience;
  /// Only reminders with a fixed item and pickup slot may offer a one-field
  /// confirm action. Generic reminders stay informational.
  final String? offeredItem;
  final String? pickupTime;

  bool get canOfferQuickConfirm =>
      (offeredItem?.trim().isNotEmpty ?? false) &&
      RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$')
          .hasMatch(pickupTime ?? '');
}

abstract final class NightReminderAudienceQuery {
  /// Every recipient passes through current approved relationship, active
  /// account AND verified opt-in before optional segment constraints.
  ///
  /// "Yesterday" = calendar day before send date in Sana'a, confirmed status.
  /// "Last week" = seven calendar days immediately before send date, any
  /// confirmed/fulfilled reservation, but never cancelled or awaiting.
  /// Favorites come only from merchant-owned, backend-verified store records.
  static List<String> recipients({
    required NightReminderAudience audience,
    required String? merchantId,
    required DateTime now,
    required Iterable<CustomerModel> customers,
    required Iterable<RelationshipModel> relationships,
    required Iterable<ReservationDraft> bookings,
    required Set<String> consentedCustomerIds,
    required Set<String> merchantFavoriteCustomerIds,
    required BookingNightReminderSettings settings,
  }) {
    final base = BookingNightReminderPolicy.preview(
      settings: settings,
      merchantId: merchantId,
      customers: customers,
      relationships: relationships,
      consentedCustomerIds: consentedCustomerIds,
      now: now,
    ).recipientIds.toSet();
    if (base.isEmpty) return const [];
    if (audience == NightReminderAudience.allApproved) {
      final result = base.toList()..sort();
      return List.unmodifiable(result);
    }
    if (audience == NightReminderAudience.favorites) {
      final result = base.intersection(merchantFavoriteCustomerIds).toList()
        ..sort();
      return List.unmodifiable(result);
    }
    final local = BookingIntakePolicy.sanaaTime(now);
    final day = DateTime.utc(local.year, local.month, local.day);
    final yesterday = day.subtract(const Duration(days: 1));
    final firstDay = day.subtract(const Duration(days: 7));
    bool isConfirmed(ReservationStatus status) =>
        status == ReservationStatus.confirmed ||
        status == ReservationStatus.preparing ||
        status == ReservationStatus.ready ||
        status == ReservationStatus.collected;
    final result = <String>{};
    for (final booking in bookings) {
      final customer = booking.customerId;
      if (booking.merchantId != merchantId ||
          customer == null || !base.contains(customer) ||
          !isConfirmed(booking.status)) continue;
      final bookingDay = DateTime.utc(booking.day.year,
          booking.day.month, booking.day.day);
      if (audience == NightReminderAudience.yesterdayConfirmed) {
        if (bookingDay == yesterday) result.add(customer);
      } else if (!bookingDay.isBefore(firstDay) &&
          bookingDay.isBefore(day)) {
        result.add(customer);
      }
    }
    return List.unmodifiable(result.toList()..sort());
  }
}

enum ReminderEngagementType { delivered, opened, confirmedBooking }

class ReminderEngagementEvent {
  const ReminderEngagementEvent({
    required this.campaignId,
    required this.merchantId,
    required this.customerId,
    required this.type,
    required this.recordedAt,
  });
  final String campaignId;
  final String merchantId;
  final String customerId;
  final ReminderEngagementType type;
  final DateTime recordedAt;
}

class ReminderEngagementSummary {
  const ReminderEngagementSummary({
    required this.recipientCount,
    required this.deliveredCount,
    required this.openedCount,
    required this.confirmedCount,
  });
  final int recipientCount;
  final int deliveredCount;
  final int openedCount;
  final int confirmedCount;
  double? get openedPercent => deliveredCount == 0
      ? null : openedCount * 100 / deliveredCount;
}

/// Events MUST originate from authenticated server telemetry. Opening a
/// notification is not the same as receiving it; no device read inference.
/// Counts are unique customers, never repeated taps or duplicate receipts.
abstract final class ReminderEngagementQuery {
  static ReminderEngagementSummary summarize({
    required String campaignId,
    required String merchantId,
    required Iterable<String> recipientIds,
    required Iterable<ReminderEngagementEvent> serverEvents,
  }) {
    final targets = recipientIds.toSet();
    final delivered = <String>{};
    final opened = <String>{};
    final confirmed = <String>{};
    for (final event in serverEvents) {
      if (event.campaignId != campaignId ||
          event.merchantId != merchantId ||
          !targets.contains(event.customerId)) continue;
      switch (event.type) {
        case ReminderEngagementType.delivered:
          delivered.add(event.customerId);
          break;
        case ReminderEngagementType.opened:
          opened.add(event.customerId);
          break;
        case ReminderEngagementType.confirmedBooking:
          confirmed.add(event.customerId);
          break;
      }
    }
    return ReminderEngagementSummary(
      recipientCount: targets.length,
      deliveredCount: delivered.length,
      openedCount: opened.intersection(delivered).length,
      confirmedCount: confirmed.intersection(delivered).length,
    );
  }
}

class ReminderBookingDecision {
  const ReminderBookingDecision({required this.allowed, required this.reason});
  final bool allowed;
  final String reason;
}

class ReminderQuickBookingRequest {
  const ReminderQuickBookingRequest({
    required this.campaignId,
    required this.merchantId,
    required this.customerId,
    required this.day,
    required this.item,
    required this.pickupTime,
    required this.quantity,
  });
  final String campaignId;
  final String merchantId;
  final String customerId;
  final DateTime day;
  final String item;
  final String pickupTime;
  final int quantity;
}

/// Validates the presentation. Backend MUST also check: logged-in customer,
/// original campaign delivery and recipient, merchant hours, relationship,
/// target date, capacity, package entitlement, and atomic idempotency.
abstract final class ReminderQuickBookingPolicy {
  static ReminderBookingDecision check({
    required NightReminderCampaignDraft campaign,
    required String? authenticatedCustomerId,
    required int quantity,
    required Set<String> verifiedDeliveredCustomerIds,
    required BookingIntakeSettings intakeSettings,
    required Iterable<CustomerModel> customers,
    required Iterable<RelationshipModel> relationships,
    required DateTime now,
  }) {
    if (!campaign.canOfferQuickConfirm) {
      return const ReminderBookingDecision(
        allowed: false, reason: 'التذكير لا يحتوي على صنف ووقت استلام محددين');
    }
    if (quantity < 1 || quantity > 10000) {
      return const ReminderBookingDecision(
        allowed: false, reason: 'عدد الربطات غير صالح');
    }
    if (authenticatedCustomerId == null ||
        !verifiedDeliveredCustomerIds.contains(authenticatedCustomerId)) {
      return const ReminderBookingDecision(
        allowed: false, reason: 'لا يوجد تذكير موثّق لهذا العميل');
    }
    final eligibility = BookingIntakePolicy.check(
      settings: intakeSettings,
      merchantId: campaign.merchantId,
      customerId: authenticatedCustomerId,
      customers: customers,
      relationships: relationships,
      now: now,
      bookingDay: campaign.day,
    );
    return ReminderBookingDecision(
      allowed: eligibility.allowed,
      reason: eligibility.reason,
    );
  }
}
