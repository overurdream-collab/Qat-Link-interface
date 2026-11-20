import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/app_models.dart';
import '../finance_display.dart';
import 'customer_statement_calculator.dart';

/// Prints a real, paginated A4 PDF by rasterizing Arabic with Flutter's
/// own shaping engine. Unlike PDF core fonts, this supports Arabic without
/// downloading a font at runtime. Report is explicitly marked as a local
/// unverified preview until server authentication and audit are connected.
abstract final class CustomerStatementPdf {
  static const _width = 794.0;
  static const _height = 1123.0;
  static const _perPage = 17;

  static Future<Uint8List> create({
    required CustomerModel customer,
    required CustomerStatement statement,
  }) async {
    final document = pw.Document();
    final rows = statement.rows;
    final pages = rows.isEmpty ? 1 : ((rows.length + _perPage - 1) ~/ _perPage);

    for (var page = 0; page < pages; page++) {
      final start = page * _perPage;
      final end = (start + _perPage).clamp(0, rows.length);
      final imageBytes = await _renderPage(
        customer: customer,
        statement: statement,
        page: page,
        pageCount: pages,
        rows: rows.sublist(start, end),
      );
      document.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(
          pw.MemoryImage(imageBytes),
          width: PdfPageFormat.a4.width,
          height: PdfPageFormat.a4.height,
          fit: pw.BoxFit.fill,
        ),
      ));
    }
    return document.save();
  }

  static Future<bool> export({
    required CustomerModel customer,
    required CustomerStatement statement,
  }) async {
    final bytes = await create(customer: customer, statement: statement);
    return Printing.layoutPdf(
      name: _fileName(statement),
      onLayout: (_) async => bytes,
    );
  }

  static Future<bool> share({
    required CustomerModel customer,
    required CustomerStatement statement,
  }) async {
    final bytes = await create(customer: customer, statement: statement);
    return Printing.sharePdf(bytes: bytes, filename: _fileName(statement));
  }

  static String _fileName(CustomerStatement statement) =>
      'maqwati_statement_${statement.customerId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}_${statement.currency.name}_${_date(statement.from)}_${_date(statement.to)}.pdf';

  static String _date(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Future<Uint8List> _renderPage({
    required CustomerModel customer,
    required CustomerStatement statement,
    required int page,
    required int pageCount,
    required List<MovementModel> rows,
  }) async {
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(scale);
    final background = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, _width, _height), background);
    final teal = const ui.Color(0xFF07575B);
    final gray = const ui.Color(0xFF52636B);
    final black = const ui.Color(0xFF142F37);

    void rectangle(double x, double y, double width, double height,
        ui.Color color, [double radius = 0]) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(x, y, width, height), ui.Radius.circular(radius)),
        ui.Paint()..color = color,
      );
    }

    void label(String text, double xRight, double y, double width,
        {double size = 15, bool bold = false,
        ui.Color color = const ui.Color(0xFF142F37),
        int lines = 1}) {
      final painter = material.TextPainter(
        text: material.TextSpan(
          text: text,
          style: material.TextStyle(
            fontSize: size,
            fontWeight: bold
                ? material.FontWeight.w700 : material.FontWeight.w400,
            color: material.Color(color.toARGB32()),
          ),
        ),
        textDirection: ui.TextDirection.rtl,
        textAlign: material.TextAlign.right,
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: width);
      painter.paint(canvas, ui.Offset(xRight - width, y));
    }

    rectangle(0, 0, _width, 102, teal);
    label('مقوتي لينك', 750, 18, 320, size: 31,
        color: const ui.Color(0xFFFFFFFF), bold: true);
    label('كشف حساب العميل • نسخة معاينة غير موثقة', 746, 60, 510,
        size: 16, color: const ui.Color(0xFFECFFFB));
    label('صفحة ${page + 1} من $pageCount', 202, 32, 158,
        size: 15, color: const ui.Color(0xFFFFFFFF));

    rectangle(36, 122, 722, 122, const ui.Color(0xFFF0F8F7), 12);
    label('العميل: ${customer.name}', 735, 133, 635, size: 20, bold: true);
    label('الجوال: ${customer.phone}', 735, 172, 600, size: 15);
    label('الفترة: ${_date(statement.from)} إلى ${_date(statement.to)}',
        735, 199, 560, size: 15);
    label('العملة: ${FinanceDisplay.currencyCode(statement.currency)}',
        220, 199, 165, size: 15, color: teal, bold: true);

    if (page == 0) {
      const labels = [
        'رصيد افتتاحي', 'ديون معتمدة', 'تحصيل معتمد',
        'عمليات معلقة', 'رصيد ختامي',
      ];
      final vals = [
        statement.openingBalance,
        statement.approvedDebts,
        statement.approvedPayments,
        statement.pendingAmount,
        statement.closingBalance,
      ];
      final cellWidth = 138.0;
      for (var i = 0; i < labels.length; i++) {
        final x = 36.0 + i * 146.0;
        rectangle(x, 261, cellWidth, 79,
            i == 4 ? const ui.Color(0xFFDDF3ED)
                : const ui.Color(0xFFF6F9FB), 10);
        label(labels[i], x + 128, 271, 118, size: 12, color: gray);
        label('${FinanceDisplay.amount(vals[i])}', x + 128, 300, 118,
            size: 16, bold: true, color: i == 4 ? teal : black);
      }
    }

    label('سجل العمليات ${statement.filter == null ? '(جميع الحالات)' : '(${_status(statement.filter!)})'}',
        751, 364, 710, size: 19, bold: true, color: teal);
    rectangle(35, 404, 724, 45, teal, 5);
    label('التاريخ', 748, 414, 95, size: 13,
        color: const ui.Color(0xFFFFFFFF), bold: true);
    label('البيان أو الوصف', 644, 414, 238, size: 13,
        color: const ui.Color(0xFFFFFFFF), bold: true);
    label('النوع', 390, 414, 64, size: 13,
        color: const ui.Color(0xFFFFFFFF), bold: true);
    label('المبلغ', 310, 414, 119, size: 13,
        color: const ui.Color(0xFFFFFFFF), bold: true);
    label('الحالة', 179, 414, 104, size: 13,
        color: const ui.Color(0xFFFFFFFF), bold: true);

    if (rows.isEmpty) {
      label('لا توجد عمليات في الفترة المحددة', 735, 475, 620,
          color: gray, size: 18);
    }
    for (var i = 0; i < rows.length; i++) {
      final tx = rows[i];
      final y = 455.0 + i * 33;
      if (i.isEven) {
        rectangle(35, y, 724, 32, const ui.Color(0xFFF4F8F8), 3);
      }
      label(_date(tx.createdAt), 748, y + 7, 95, size: 12);
      label(tx.description?.trim().isNotEmpty == true
            ? tx.description! : (tx.type == MovementType.debt
              ? 'تسجيل دين' : 'تسديد'),
          644, y + 7, 238, size: 12);
      label(tx.type == MovementType.debt ? 'دين' : 'تسديد',
          390, y + 7, 64, size: 12);
      label(FinanceDisplay.amount(tx.amount), 310, y + 7, 119,
          size: 12, bold: true);
      label(_status(tx.status), 179, y + 7, 104,
          size: 11,
          color: tx.status == MovementStatus.rejected
              ? const ui.Color(0xFFC04444)
              : tx.status == MovementStatus.pending
                  ? const ui.Color(0xFF92400E) : teal);
    }
    rectangle(36, 1050, 722, 1, const ui.Color(0xFFD9E7E7));
    label('العمليات المعلقة والمرفوضة لا تغير الرصيد المعتمد.',
        749, 1058, 700, size: 12, color: gray);
    label('هذا الكشف من بيانات محلية غير موثقة؛ يتطلب الاعتماد الخادمي للاستخدام الرسمي.',
        749, 1080, 700, size: 11, color: gray);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
        (_width * scale).toInt(), (_height * scale).toInt());
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('تعذر إنشاء صورة الصفحة للطباعة');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  static String _status(MovementStatus status) => switch (status) {
    MovementStatus.approved => 'معتمدة',
    MovementStatus.pending => 'عالقة',
    MovementStatus.rejected => 'مرفوضة',
  };
}
