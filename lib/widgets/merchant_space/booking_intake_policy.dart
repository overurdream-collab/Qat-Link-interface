import '../../models/app_models.dart';

/// Policy for customer-facing booking intake. UI previews must never be
/// mistaken for backend authorization or proof of successful submission.
class BookingIntakeSettings {
  const BookingIntakeSettings({
    this.enabled = false,
    this.allDay = false,
    this.opensAtMinute = 8 * 60,
    this.closesAtMinute = 20 * 60,
  }) : assert(opensAtMinute >= 0 && opensAtMinute < 1440),
       assert(closesAtMinute >= 0 && closesAtMinute < 1440);

  final bool enabled;
  final bool allDay;
  final int opensAtMinute;
  final int closesAtMinute;

  bool get valid => allDay || opensAtMinute != closesAtMinute;

  BookingIntakeSettings copyWith({
    bool? enabled, bool? allDay,
    int? opensAtMinute, int? closesAtMinute,
  }) => BookingIntakeSettings(
    enabled: enabled ?? this.enabled,
    allDay: allDay ?? this.allDay,
    opensAtMinute: opensAtMinute ?? this.opensAtMinute,
    closesAtMinute: closesAtMinute ?? this.closesAtMinute,
  );
}

class BookingEligibility {
  const BookingEligibility({required this.allowed, required this.reason});
  final bool allowed;
  final String reason;
}

abstract final class BookingIntakePolicy {
  /// Fixed Yemen time (Asia/Aden: UTC+03, no DST). The server is authoritative.
  static DateTime sanaaTime(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 3));

  static bool isWindowOpen(BookingIntakeSettings settings, DateTime now) {
    if (!settings.enabled || !settings.valid) return false;
    if (settings.allDay) return true;
    final local = sanaaTime(now);
    final minute = local.hour * 60 + local.minute;
    if (settings.opensAtMinute < settings.closesAtMinute) {
      return minute >= settings.opensAtMinute &&
          minute < settings.closesAtMinute;
    }
    // Overnight window e.g. 20:00 to 02:00.
    return minute >= settings.opensAtMinute ||
        minute < settings.closesAtMinute;
  }

  static BookingEligibility check({
    required BookingIntakeSettings settings,
    required String? merchantId,
    required String? customerId,
    required Iterable<CustomerModel> customers,
    required Iterable<RelationshipModel> relationships,
    required DateTime now,
    required DateTime bookingDay,
  }) {
    if (merchantId == null || merchantId.trim().isEmpty ||
        customerId == null || customerId.trim().isEmpty) {
      return const BookingEligibility(
          allowed: false, reason: 'يلزم تسجيل الدخول بحساب عميل وتاجر موثق');
    }
    if (!settings.enabled) {
      return const BookingEligibility(
          allowed: false, reason: 'باب الحجوزات مغلق حالياً');
    }
    if (!settings.valid) {
      return const BookingEligibility(
          allowed: false, reason: 'ساعات استقبال الحجوزات غير صحيحة');
    }
    if (!isWindowOpen(settings, now)) {
      return const BookingEligibility(
          allowed: false, reason: 'الوقت خارج ساعات استقبال الحجوزات');
    }
    final sanaa = sanaaTime(now);
    final today = DateTime.utc(sanaa.year, sanaa.month, sanaa.day);
    final requested = DateTime.utc(
        bookingDay.year, bookingDay.month, bookingDay.day);
    if (requested.isBefore(today)) {
      return const BookingEligibility(
          allowed: false, reason: 'لا يمكن إنشاء حجز ليوم مضى');
    }
    if (!customers.any((c) => c.id == customerId &&
        c.accountStatus == AccountStatus.active)) {
      return const BookingEligibility(
          allowed: false, reason: 'الحساب غير نشط أو غير مسجل');
    }
    if (!relationships.any((r) =>
        r.merchantId == merchantId &&
        r.customerId == customerId &&
        r.status == RelationshipStatus.approved)) {
      return const BookingEligibility(
          allowed: false, reason: 'الحجز متاح فقط للعملاء المرتبطين بالتاجر بموافقة الطرفين');
    }
    return const BookingEligibility(allowed: true, reason: '');
  }
}

class BookingNightReminderSettings {
  const BookingNightReminderSettings({
    this.enabled = false,
    this.sendAtMinute = 20 * 60,
  }) : assert(sendAtMinute >= 0 && sendAtMinute < 1440);
  final bool enabled;
  final int sendAtMinute;

  BookingNightReminderSettings copyWith({
    bool? enabled, int? sendAtMinute,
  }) => BookingNightReminderSettings(
    enabled: enabled ?? this.enabled,
    sendAtMinute: sendAtMinute ?? this.sendAtMinute,
  );
}

class BookingNightReminderPreview {
  const BookingNightReminderPreview({
    required this.recipientIds,
    required this.sendAtSanaa,
    required this.bookingForDay,
  });
  final List<String> recipientIds;
  final DateTime sendAtSanaa;
  final DateTime bookingForDay;
}

/// Preview only. Real recurring scheduling requires a secure backend, customer
/// notification preferences, rate limits, idempotency and permission checks.\n/// Never treat the approved relationship itself as permission to send\n/// optional promotional booking reminders.
abstract final class BookingNightReminderPolicy {
  static BookingNightReminderPreview preview({
    required BookingNightReminderSettings settings,
    required String? merchantId,
    required Iterable<CustomerModel> customers,
    required Iterable<RelationshipModel> relationships,
    /// Server-verified customers currently opting into optional store alerts.
    /// Unknown or missing preferences grant no permission.
    required Set<String> consentedCustomerIds,
    required DateTime now,
  }) {
    final sanaa = BookingIntakePolicy.sanaaTime(now);
    final date = DateTime.utc(sanaa.year, sanaa.month, sanaa.day);
    final sendAt = date.add(Duration(minutes: settings.sendAtMinute));
    final sendDate = sendAt.isAfter(sanaa) ? sendAt
        : sendAt.add(const Duration(days: 1));
    final tomorrow = DateTime.utc(sendDate.year, sendDate.month,
        sendDate.day + 1);
    final approved = <String>{};
    if (settings.enabled && merchantId != null &&
        merchantId.trim().isNotEmpty) {
      for (final r in relationships) {
        if (r.merchantId == merchantId &&
            r.status == RelationshipStatus.approved) {
          approved.add(r.customerId);
        }
      }
    }
    final targets = customers.where((c) =>
        c.accountStatus == AccountStatus.active &&
        approved.contains(c.id) &&
        consentedCustomerIds.contains(c.id)).map((c) => c.id).toList()..sort();
    return BookingNightReminderPreview(
      recipientIds: List.unmodifiable(targets),
      sendAtSanaa: sendDate,
      bookingForDay: tomorrow,
    );
  }
}
