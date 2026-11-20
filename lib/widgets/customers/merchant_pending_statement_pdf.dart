import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart' as material;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/app_models.dart';
import '../../models/merchant_pending_models.dart';
import '../finance_display.dart';
import 'pdf_brand_mascot.dart';

/// Arabic PDF for a merchant-only record. It is deliberately marked as
/// unverified on every page and keeps all currencies separate.
abstract final class MerchantPendingStatementPdf {
  static const _width = 794.0;
  static const _height = 1123.0;
  static const _rowsPerPage = 15;

  static Future<Uint8List> create(MerchantPendingStatement statement) async {
    final rows = <_PdfRow>[
      for (final debt in statement.rows)
        _PdfRow(debt.createdAt, 'دين مسجل', debt.description,
            debt.amount, debt.currency, false),
      for (final payment in statement.paymentRows)
        _PdfRow(payment.createdAt, 'دفعة مسجلة', payment.description,
            payment.amount, payment.currency, true),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final pageCount = rows.isEmpty ? 1 : (rows.length / _rowsPerPage).ceil();
    final document = pw.Document();
    for (var page = 0; page < pageCount; page++) {
      final start = page * _rowsPerPage;
      final end = (start + _rowsPerPage).clamp(0, rows.length);
      final image = await _renderPage(
        statement: statement,
        rows: rows.sublist(start, end),
        page: page,
        pageCount: pageCount,
      );
      document.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(image),
            width: PdfPageFormat.a4.width,
            height: PdfPageFormat.a4.height,
            fit: pw.BoxFit.fill),
      ));
    }
    return document.save();
  }

  static Future<Uint8List> _renderPage({
    required MerchantPendingStatement statement,
    required List<_PdfRow> rows,
    required int page,
    required int pageCount,
  }) async {
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(scale);
    final teal = const ui.Color(0xFF07575B);
    final ink = const ui.Color(0xFF142F37);
    final muted = const ui.Color(0xFF52636B);
    final rose = const ui.Color(0xFFC04444);

    void box(double x, double y, double w, double h, ui.Color color,
        {double radius = 0}) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(x, y, w, h), ui.Radius.circular(radius)),
        ui.Paint()..color = color,
      );
    }

    void text(String value, double xRight, double y, double width,
        {double size = 14, bool bold = false,
        ui.Color color = const ui.Color(0xFF142F37), int lines = 1}) {
      final painter = material.TextPainter(
        text: material.TextSpan(text: value, style: material.TextStyle(
          fontSize: size,
          fontWeight: bold ? material.FontWeight.w700 : material.FontWeight.w400,
          color: material.Color(color.toARGB32()),
        )),
        textDirection: ui.TextDirection.rtl,
        textAlign: material.TextAlign.right,
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: width);
      painter.paint(canvas, ui.Offset(xRight - width, y));
    }

    String date(DateTime value) => '${value.year}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';

    box(0, 0, _width, 108, teal);
    await PdfBrandMascot.draw(canvas, x: 24, y: 18, size: 70);
    text('مقوتي لينك', 752, 15, 400, size: 29,
        bold: true, color: const ui.Color(0xFFFFFFFF));
    text('كشف حساب مسجل لدى التاجر — غير معتمد من العميل', 752, 59, 700,
        size: 16, bold: true, color: const ui.Color(0xFFFFE7AD));
    text('صفحة ${page + 1} من $pageCount', 306, 25, 170,
        size: 12, color: const ui.Color(0xFFFFFFFF));

    box(36, 127, 722, 118, const ui.Color(0xFFF4F9F8), radius: 11);
    text('العميل المسجل لدى التاجر: ${statement.contact.name}', 733, 140, 660,
        size: 18, bold: true);
    text('هاتف التواصل: ${statement.contact.phone}', 733, 174, 620, size: 13);
    text('الفترة: ${date(statement.from)} إلى ${date(statement.to)}',
        733, 202, 620, size: 13, color: muted);

    text('ملخص الحركة حسب العملة', 750, 263, 700,
        size: 17, bold: true, color: teal);
    var summaryY = 294.0;
    for (final currency in CurrencyCode.values) {
      final debts = statement.byCurrency[currency];
      final payments = statement.paymentsByCurrency[currency];
      if (debts == null && payments == null) continue;
      box(36, summaryY, 722, 47, const ui.Color(0xFFF6FAFA), radius: 7);
      final debtValue = debts ?? Decimal.zero;
      final paymentValue = payments ?? Decimal.zero;
      final net = debtValue - paymentValue;
      text(FinanceDisplay.currencyCode(currency), 740, summaryY + 13, 80,
          size: 13, bold: true, color: teal);
      text('ديون: ${FinanceDisplay.amount(debtValue)}', 640,
          summaryY + 13, 190, size: 12, color: ink);
      text('دفعات: ${FinanceDisplay.amount(paymentValue)}', 434,
          summaryY + 13, 190, size: 12, color: ink);
      text('الصافي: ${FinanceDisplay.amount(net)}', 228,
          summaryY + 13, 188, size: 11, bold: true,
          color: net < Decimal.zero ? teal : ink);
      summaryY += 54;
    }

    final tableY = summaryY + 11;
    text('سجل الحركة', 750, tableY, 700,
        size: 17, bold: true, color: teal);
    box(36, tableY + 30, 722, 39, teal, radius: 4);
    text('التاريخ', 743, tableY + 41, 95,
        size: 11, bold: true, color: const ui.Color(0xFFFFFFFF));
    text('نوع العملية / الوصف', 639, tableY + 41, 260,
        size: 11, bold: true, color: const ui.Color(0xFFFFFFFF));
    text('المبلغ والعملة', 363, tableY + 41, 180,
        size: 11, bold: true, color: const ui.Color(0xFFFFFFFF));
    text('الحالة', 177, tableY + 41, 90,
        size: 11, bold: true, color: const ui.Color(0xFFFFFFFF));
    if (rows.isEmpty) {
      text('لا توجد حركات في الفترة المحددة', 735, tableY + 83, 650,
          size: 15, color: muted);
    }
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final y = tableY + 72 + index * 31.0;
      if (index.isEven) box(36, y, 722, 30, const ui.Color(0xFFF4F8F8), radius: 3);
      text(date(row.date), 743, y + 7, 95, size: 10, color: ink);
      text('${row.kind}${row.description == null ? '' : ' • ${row.description}'}',
          639, y + 7, 260, size: 10, color: ink);
      text('${row.payment ? '−' : '+'}${FinanceDisplay.amount(row.amount)} '
          '${FinanceDisplay.currencyCode(row.currency)}', 363, y + 7, 180,
          size: 10, bold: true, color: row.payment ? teal : ink);
      text('معلقة', 177, y + 7, 90, size: 10, color: rose);
    }

    box(36, 1041, 722, 1, const ui.Color(0xFFDBE9EB));
    text('هذا البيان صادر من سجل التاجر وحده؛ لم يوافق العميل على العلاقة أو المبالغ، '
        'ولا يعد إقراراً بالدين أو كشفاً معتمداً.', 750, 1051, 710,
        size: 10, color: muted, lines: 2);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (_width * scale).toInt(), (_height * scale).toInt());
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('تعذر إنشاء صفحة الكشف.');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

class _PdfRow {
  const _PdfRow(this.date, this.kind, this.description, this.amount,
      this.currency, this.payment);
  final DateTime date;
  final String kind;
  final String? description;
  final Decimal amount;
  final CurrencyCode currency;
  final bool payment;
}
