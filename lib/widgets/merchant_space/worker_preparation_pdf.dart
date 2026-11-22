import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'merchant_space_models.dart';

/// Employee-only preparation report: large text, no telephone numbers,
/// no prices, no balances, and no customer account identifiers.
abstract final class WorkerPreparationPdf {
  static const double _w = 794, _h = 1123;
  static const int _perPage = 10;
  static String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Future<Uint8List> generate({
    required DateTime day,
    required String storeName,
    required ReservationDailySummary summary,
  }) async {
    final active = summary.orders
        .where((r) =>
            r.status != ReservationStatus.cancelled &&
            r.status != ReservationStatus.collected)
        .toList();
    final pages =
        active.isEmpty ? 1 : (active.length + _perPage - 1) ~/ _perPage;
    final doc = pw.Document();
    for (var p = 0; p < pages; p++) {
      final start = p * _perPage;
      final end = (start + _perPage).clamp(0, active.length);
      final bytes = await _page(
        day: day,
        storeName: storeName,
        summary: summary,
        rows: active.sublist(start, end),
        index: p,
        pageCount: pages,
      );
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(
          pw.MemoryImage(bytes),
          fit: pw.BoxFit.fill,
          width: PdfPageFormat.a4.width,
          height: PdfPageFormat.a4.height,
        ),
      ));
    }
    return doc.save();
  }

  static Future<bool> share(Uint8List bytes, DateTime day) => Printing.sharePdf(
        bytes: bytes,
        filename: 'maqwati_workers_${_date(day)}.pdf',
      );

  static Future<bool> print(Uint8List bytes, DateTime day) =>
      Printing.layoutPdf(
        name: 'maqwati_workers_${_date(day)}.pdf',
        onLayout: (_) async => bytes,
      );

  static Future<Uint8List> _page({
    required DateTime day,
    required String storeName,
    required ReservationDailySummary summary,
    required List<ReservationDraft> rows,
    required int index,
    required int pageCount,
  }) async {
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(scale);
    const ink = ui.Color(0xFF111A4B);
    const teal = ui.Color(0xFF3653B8);
    const pale = ui.Color(0xFFF2F3FF);
    const white = ui.Color(0xFFFFFFFF);

    void rect(double x, double y, double w, double h, ui.Color color) {
      canvas.drawRect(ui.Rect.fromLTWH(x, y, w, h), ui.Paint()..color = color);
    }

    void write(String content, double right, double top, double width,
        {double size = 20, bool bold = false, ui.Color color = ink}) {
      final painter = material.TextPainter(
        text: material.TextSpan(
            text: content,
            style: material.TextStyle(
              fontSize: size,
              color: material.Color(color.toARGB32()),
              fontWeight:
                  bold ? material.FontWeight.w800 : material.FontWeight.w500,
            )),
        textDirection: ui.TextDirection.rtl,
        textAlign: material.TextAlign.right,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: width);
      painter.paint(canvas, ui.Offset(right - width, top));
    }

    rect(0, 0, _w, _h, white);
    rect(0, 0, _w, 143, teal);
    write('كشف تجهيز العمال', 751, 15, 680, size: 34, bold: true, color: white);
    write(storeName, 749, 69, 660, size: 23, color: white);
    write(
        'اليوم: ${_date(day)}     صفحة ${index + 1}/$pageCount', 750, 106, 665,
        size: 19, color: white);

    rect(35, 158, 724, 98, pale);
    write('إجمالي الطلبات: ${summary.activeCount}', 745, 166, 680,
        size: 23, bold: true);
    write('الربطات المطلوب تجهيزها: ${summary.totalBundles}', 745, 204, 680,
        size: 23, bold: true);
    write('الطلبات مرتبة حسب وقت الاستلام', 744, 270, 680, size: 17);
    rect(35, 311, 724, 50, teal);
    write('العميل', 741, 320, 208, size: 20, bold: true, color: white);
    write('الصنف', 517, 320, 188, size: 20, bold: true, color: white);
    write('العدد', 312, 320, 75, size: 20, bold: true, color: white);
    write('الوقت', 218, 320, 105, size: 20, bold: true, color: white);

    if (rows.isEmpty) {
      write('لا توجد طلبات تجهيز لهذا اليوم', 742, 399, 675,
          size: 24, bold: true);
    }
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final y = 369.0 + i * 66.0;
      if (i.isEven) rect(35, y, 724, 65, pale);
      write(r.customerName, 741, y + 12, 208, size: 19, bold: true);
      write(r.item, 517, y + 12, 188, size: 19);
      write('${r.bundles}', 312, y + 10, 75, size: 25, bold: true);
      write(r.pickupTime, 218, y + 12, 105, size: 20);
    }
    rect(35, 1060, 724, 1, const ui.Color(0xFFE0E3F9));
    write('نسخة للتجهيز فقط • لا تتضمن بيانات مالية أو أرقام هواتف', 751, 1072,
        695,
        size: 15);
    write('مسودة محلية: تأكد من مطابقة الطلبات قبل التسليم', 751, 1091, 695,
        size: 14);
    final picture = recorder.endRecording();
    final image =
        await picture.toImage((_w * scale).toInt(), (_h * scale).toInt());
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Failed to render worker report');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
