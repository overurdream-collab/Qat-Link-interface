import 'package:decimal/decimal.dart';

import '../models/app_models.dart';
import 'fin08_api_client.dart';

/// A MANUALLY shared, explicitly disputed/unacknowledged merchant statement.
/// It is NOT an approved ledger statement and never changes balances.
abstract final class Fin08PendingStatement {
  static bool isPending(Fin08MerchantClaim c) =>
      c.stage != Fin08Stage.approved && c.stage != Fin08Stage.rejected;

  /// Display at least two fractional digits without rounding or converting
  /// Decimal to binary floating point. Preserve higher precision when present.
  static String formatSubtotal(Decimal amount) {
    final raw = amount.toString();
    final separator = raw.indexOf('.');
    if (separator < 0) return '$raw.00';
    final fractionalDigits = raw.length - separator - 1;
    return fractionalDigits >= 2
        ? raw
        : '${raw}${'0' * (2 - fractionalDigits)}';
  }

  static String compose({
    required Fin08MerchantContact contact,
    required Iterable<Fin08MerchantClaim> claims,
  }) {
    final rows=claims.where(isPending).toList(growable:false)
      ..sort((a,b){
        final byDate=a.createdAt.compareTo(b.createdAt);
        return byDate==0?a.id.compareTo(b.id):byDate;
      });
    final totals=<CurrencyCode,Decimal>{};
    for(final claim in rows){
      totals.update(claim.currency,(prev)=>prev+claim.amount,ifAbsent:()=>claim.amount);
    }
    String date(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    final text=StringBuffer()
      ..writeln('كشف مبالغ مسجلة في دفتر التاجر — معلقة وغير معتمدة')
      ..writeln('اسم العميل في سجل التاجر: ${contact.name}')
      ..writeln('الهاتف المسجل: ${contact.phone}')
      ..writeln('عدد المطالبات غير المعتمدة: ${rows.length}')
      ..writeln('---');
    if(rows.isEmpty)text.writeln('لا توجد مطالبات معلقة حالياً.');
    for(final claim in rows){
      text.writeln('${date(claim.createdAt)} | ${claim.amount} ${claim.currency.name.toUpperCase()} | '
        '${claim.stage.label} | ${claim.description?.trim().isNotEmpty==true ? claim.description!.trim() : 'مبلغ مسجل من التاجر'}');
    }
    text.writeln('---');
    for(final currency in CurrencyCode.values){
      final sum=totals[currency];
      if(sum!=null)text.writeln('مجموع المبالغ المعلقة (${currency.name.toUpperCase()}): ${formatSubtotal(sum)}');
    }
    text.writeln('تنبيه: هذا بيان صادر من سجل التاجر وحده، لا يُعد إقراراً من العميل '
      'ولا يتضمن المبالغ المرفوضة أو المعتمدة أو المدفوعات. '
      'لا يؤثر على الرصيد المعتمد. يرجى مراجعة كل طلب عند الانضمام للتطبيق.');
    return text.toString();
  }
}