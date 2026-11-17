import 'package:decimal/decimal.dart';

import 'app_models.dart';

/// A private merchant-address-book contact, NOT a registered user identity.
/// Matching a phone number never proves ownership of the customer's account.
class MerchantPendingContact {
  const MerchantPendingContact({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.phone,
    required this.createdAt,
  });

  final String id;
  final String merchantId;
  final String name;
  final String phone;
  final DateTime createdAt;
}

/// Link supplied ONLY by the authenticated server after verifying that
/// the new customer owns the phone number of this private merchant contact.
///
/// It permits delivery of ALL historical claims into a *pending review inbox*,
/// even when the merchant/customer relationship has not been approved.
/// It does NOT indicate acceptance of the merchant's claims or relationship.
class VerifiedCustomerContactMatch {
  const VerifiedCustomerContactMatch({
    required this.merchantId,
    required this.contactId,
    required this.customerId,
    required this.verifiedAt,
  });

  final String merchantId;
  final String contactId;
  final String customerId;
  final DateTime verifiedAt;
}

/// A separately recorded decision on a pre-registration claim. The server
/// must authenticate customerId and make a UNIQUE (merchantId, claimId,
/// customerId) decision. Acceptance here never creates an approved balance
/// unless the relationship is also approved and a corresponding approved
/// MovementModel is written by the backend.
enum PreRegistrationClaimDecision { accept, reject }

class VerifiedCustomerClaimDecision {
  const VerifiedCustomerClaimDecision({
    required this.merchantId,
    required this.claimId,
    required this.customerId,
    required this.decision,
    required this.decidedAt,
  });

  final String merchantId;
  final String claimId;
  final String customerId;
  final PreRegistrationClaimDecision decision;
  final DateTime decidedAt;
}

/// Merchant-authored, UNACKNOWLEDGED claim for a contact who may not have
/// installed the app or accepted a relationship. It is never a MovementModel
/// and it must never enter the customer's recognized/approved balance.
///
/// In production these records require durable, tenant-scoped backend storage.
/// Only verified customer registration + explicit link approval + a SEPARATE
/// debt approval may produce a corresponding approved MovementModel.
class MerchantPendingDebt {
  MerchantPendingDebt({
    required this.id,
    required this.merchantId,
    required this.contactId,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.description,
  }) {
    if (amount <= Decimal.zero) {
      throw ArgumentError.value(amount, 'amount', 'Debt must be positive.');
    }
  }

  final String id;
  final String merchantId;
  final String contactId;
  final Decimal amount;
  final CurrencyCode currency;
  final DateTime createdAt;
  final String? description;
}

/// Merchant-entered payment for an unjoined contact. It lowers the merchant's
/// operational net for its currency but is not part of the shared approved
/// balance until the verified customer reviews and approves it.
class MerchantPendingPayment {
  MerchantPendingPayment({
    required this.id,
    required this.merchantId,
    required this.contactId,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.description,
  }) {
    if (amount <= Decimal.zero) {
      throw ArgumentError.value(amount, 'amount', 'Payment must be positive.');
    }
  }

  final String id;
  final String merchantId;
  final String contactId;
  final Decimal amount;
  final CurrencyCode currency;
  final DateTime createdAt;
  final String? description;
}

/// A report intended for the trader to share externally, labelled unverified.
/// It is a unilateral claim, not evidence that the recipient owes the money.
class MerchantPendingStatement {
  const MerchantPendingStatement({
    required this.contact,
    required this.from,
    required this.to,
    required this.byCurrency,
    required this.rows,
    this.paymentsByCurrency = const {},
    this.paymentRows = const [],
  });

  final MerchantPendingContact contact;
  final DateTime from;
  final DateTime to;
  final Map<CurrencyCode, Decimal> byCurrency;
  final List<MerchantPendingDebt> rows;
  final Map<CurrencyCode, Decimal> paymentsByCurrency;
  final List<MerchantPendingPayment> paymentRows;

  Map<CurrencyCode, Decimal> get operationalNetByCurrency {
    final currencies = {...byCurrency.keys, ...paymentsByCurrency.keys};
    return Map.unmodifiable({
      for (final currency in currencies)
        currency: (byCurrency[currency] ?? Decimal.zero) -
            (paymentsByCurrency[currency] ?? Decimal.zero),
    });
  }
}

/// Pure, tenant-scoped math. No cross-currency sums and no changes to ledger.
abstract final class MerchantPendingDebtQuery {
  static MerchantPendingStatement statement({
    required String? merchantId,
    required MerchantPendingContact contact,
    required Iterable<MerchantPendingDebt> debts,
    Iterable<MerchantPendingPayment> payments = const [],
    required DateTime from,
    required DateTime to,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive = DateTime(to.year, to.month, to.day + 1);
    if (!start.isBefore(endExclusive)) {
      throw ArgumentError('Statement dates are invalid.');
    }
    if (merchantId == null || merchantId.trim().isEmpty ||
        merchantId != contact.merchantId) {
      throw StateError('Verified merchant identity is required.');
    }

    final rows = debts.where((d) =>
        d.merchantId == merchantId && d.contactId == contact.id &&
        !d.createdAt.isBefore(start) &&
        d.createdAt.isBefore(endExclusive)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final totals = <CurrencyCode, Decimal>{};
    for (final debt in rows) {
      totals.update(debt.currency, (value) => value + debt.amount,
          ifAbsent: () => debt.amount);
    }
    final paymentRows = payments.where((payment) =>
        payment.merchantId == merchantId &&
        payment.contactId == contact.id &&
        !payment.createdAt.isBefore(start) &&
        payment.createdAt.isBefore(endExclusive)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final paymentTotals = <CurrencyCode, Decimal>{};
    for (final payment in paymentRows) {
      paymentTotals.update(payment.currency, (value) => value + payment.amount,
          ifAbsent: () => payment.amount);
    }
    return MerchantPendingStatement(
      contact: contact,
      from: start,
      to: DateTime(to.year, to.month, to.day),
      byCurrency: Map.unmodifiable(totals),
      rows: List.unmodifiable(rows),
      paymentsByCurrency: Map.unmodifiable(paymentTotals),
      paymentRows: List.unmodifiable(paymentRows),
    );
  }

  /// Explicitly labelled disclosure. Never claim "approved" or "invoice paid".
  /// The merchant copies it and chooses the recipient in their own messenger.
  static String shareText(MerchantPendingStatement report) {
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final buffer = StringBuffer()
      ..writeln('كشف مبالغ مسجلة لدى التاجر — معلقة وغير معتمدة من العميل')
      ..writeln('اسم العميل المسجل لدى التاجر: ${report.contact.name}')
      ..writeln('هاتف التواصل: ${report.contact.phone}')
      ..writeln('الفترة: ${date(report.from)} إلى ${date(report.to)}')
      ..writeln('---');
    if (report.rows.isEmpty && report.paymentRows.isEmpty) {
      buffer.writeln('لا توجد مبالغ معلقة في هذه الفترة.');
    }
    for (final debt in report.rows) {
      buffer.writeln('${date(debt.createdAt)} | دين مسجل | '
          '${debt.description?.trim().isNotEmpty == true ? debt.description!.trim() : 'مديونية مسجلة من التاجر'}'
          ' | ${debt.amount} ${debt.currency.name.toUpperCase()}');
    }
    for (final payment in report.paymentRows) {
      buffer.writeln('${date(payment.createdAt)} | دفعة مسجلة لدى التاجر | '
          '${payment.description?.trim().isNotEmpty == true ? payment.description!.trim() : 'تسديد مسجل من التاجر'}'
          ' | ${payment.amount} ${payment.currency.name.toUpperCase()}');
    }
    buffer.writeln('---');
    for (final currency in CurrencyCode.values) {
      final amount = report.byCurrency[currency];
      if (amount != null) {
        buffer.writeln('الديون المسجلة المعلقة: $amount ${currency.name.toUpperCase()}');
      }
      final paid = report.paymentsByCurrency[currency];
      if (paid != null) {
        buffer.writeln('الدفعات المسجلة المعلقة: $paid ${currency.name.toUpperCase()}');
      }
      final net = report.operationalNetByCurrency[currency];
      if (net != null) {
        buffer.writeln('صافي المديونية التشغيلية المسجل: $net ${currency.name.toUpperCase()}');
      }
    }
    buffer.writeln('تنبيه: هذا بيان من سجل التاجر وحده؛ '
        'لم يوافق العميل على الارتباط أو هذه المبالغ، '
        'ولا يُعد إقراراً بالدين أو كشفاً معتمداً.');
    return buffer.toString();
  }
}
