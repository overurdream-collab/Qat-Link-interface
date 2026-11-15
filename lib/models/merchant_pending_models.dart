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

/// A report intended for the trader to share externally, labelled unverified.
/// It is a unilateral claim, not evidence that the recipient owes the money.
class MerchantPendingStatement {
  const MerchantPendingStatement({
    required this.contact,
    required this.from,
    required this.to,
    required this.byCurrency,
    required this.rows,
  });

  final MerchantPendingContact contact;
  final DateTime from;
  final DateTime to;
  final Map<CurrencyCode, Decimal> byCurrency;
  final List<MerchantPendingDebt> rows;
}

/// Pure, tenant-scoped math. No cross-currency sums and no changes to ledger.
abstract final class MerchantPendingDebtQuery {
  static MerchantPendingStatement statement({
    required String? merchantId,
    required MerchantPendingContact contact,
    required Iterable<MerchantPendingDebt> debts,
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
    return MerchantPendingStatement(
      contact: contact,
      from: start,
      to: DateTime(to.year, to.month, to.day),
      byCurrency: Map.unmodifiable(totals),
      rows: List.unmodifiable(rows),
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
    if (report.rows.isEmpty) {
      buffer.writeln('لا توجد مبالغ معلقة في هذه الفترة.');
    }
    for (final debt in report.rows) {
      buffer.writeln('${date(debt.createdAt)} | '
          '${debt.description?.trim().isNotEmpty == true ? debt.description!.trim() : 'مديونية مسجلة من التاجر'}'
          ' | ${debt.amount} ${debt.currency.name.toUpperCase()}');
    }
    buffer.writeln('---');
    for (final currency in CurrencyCode.values) {
      final amount = report.byCurrency[currency];
      if (amount != null) {
        buffer.writeln('المبلغ المعلق: $amount ${currency.name.toUpperCase()}');
      }
    }
    buffer.writeln('تنبيه: هذا بيان من سجل التاجر وحده؛ '
        'لم يوافق العميل على الارتباط أو هذه المبالغ، '
        'ولا يُعد إقراراً بالدين أو كشفاً معتمداً.');
    return buffer.toString();
  }
}
