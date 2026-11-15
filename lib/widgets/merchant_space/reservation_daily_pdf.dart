import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'merchant_space_models.dart';

/// Daily preparation report — generates a genuine A4 PDF, locally, with
/// Arabic labels rasterized through Flutter TextPainter.
/// The generated file is marked "local draft": no customer verification.
abstract final class ReservationDailyPdf {
  static const double _width = 794;
  static const double _height = 1123;
  static const int _perPage = 20;

  static String _date(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static Future<Uint8List> generate({
    required DateTime day,
    required String storeName,
    required String? governorate,
    required String marketName,
    required ReservationDailySummary summary,
  }) async {
    final doc = pw.Document();
    final rows = summary.orders;
    final pages = rows.isEmpty ? 1 : (rows.length + _perPage - 1) ~/ _perPage;
    for (var page = 0; page < pages; page++) {
      final start = page * _perPage;
      final end = (start + _perPage).clamp(0, rows.length);
      final bytes = await _renderPage(
        day: day,
        storeName: storeName,
        governorate: governorate,
        marketName: marketName,
        summary: summary,
        rows: rows.sublist(start, end),
        page: page,
        pages: pages,
      );
      doc.addPage(pw.Page(
        margin: pw.EdgeInsets.zero,
        pageFormat: PdfPageFormat.a4,
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

  static Future<bool> printFile(Uint8List pdf, {
    required DateTime day,
  }) => Printing.layoutPdf(
    name: 'maqwati_preparation_${_date(day)}.pdf',
    onLayout: (_) async => pdf,
  );

  static Future<bool> shareFile(Uint8List pdf, {
    required DateTime day,
  }) => Printing.sharePdf(
    bytes: pdf, filename: 'maqwati_preparation_${_date(day)}.pdf',
  );

  static Future<Uint8List> _renderPage({
    required DateTime day,
    required String storeName,
    required String? governorate,
    required String marketName,
    required ReservationDailySummary summary,
    required List<ReservationDraft> rows,
    required int page,
    required int pages,
  }) async {
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(scale);
    const petrol = ui.Color(0xFF176B70);
    const text = ui.Color(0xFF172B30);
    const muted = ui.Color(0xFF566A71);
    const white = ui.Color(0xFFFFFFFF);
    const pale = ui.Color(0xFFF2F8F7);

    void fill(double x, double y, double w, double h, ui.Color color) {
      canvas.drawRect(ui.Rect.fromLTWH(x,y,w,h),
          ui.Paint()..color=color);
    }
    void label(String value, double right, double top, double maxWidth, {
      double size = 14, bool bold = false, ui.Color color = text,
      int maxLines = 1,
    }) {
      final painter = material.TextPainter(
        textDirection: ui.TextDirection.rtl,
        textAlign: material.TextAlign.right,
        maxLines: maxLines,
        ellipsis: '…',
        text: material.TextSpan(
          text: value,
          style: material.TextStyle(
            fontSize: size,
            fontWeight: bold
                ? material.FontWeight.w700 : material.FontWeight.w400,
            color: material.Color(color.toARGB32()),
          ),
        ),
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, ui.Offset(right-maxWidth, top));
    }

    fill(0,0,_width,_height,white);
    fill(0,0,_width,108,petrol);
    label('مقوتي لنك • كشف تجهيز الحجوزات', 755, 14, 665,
      size: 28, bold: true, color: white);
    label('نسخة محلية غير متزامنة — ليست إثبات حجز مؤكد',
      749, 65, 695, size: 14, color: white);
    label('صفحة ${page+1} من $pages', 200, 85, 150,
      color: white, size: 11);

    fill(34,128,728,129,pale);
    label('المتجر: $storeName', 742, 139, 665,
      size: 18, bold: true);
    label('الموقع: ${governorate ?? 'غير محدد'}'
        '${marketName.trim().isEmpty ? '' : ' • $marketName'}',
      742, 170, 665, size: 13, color: muted);
    label('التاريخ: ${_date(day)}', 742, 196, 660,
      size: 14, bold: true);
    label('الحجوزات النشطة: ${summary.activeCount}    '
      'الربطات المطلوبة: ${summary.totalBundles}    '
      'جاهز: ${summary.readyCount}',
      742, 227, 670, size: 13, color: petrol, bold: true);

    if (page == 0) {
      label('ملخص تجهيز الأصناف', 749, 275, 680,
        size: 18, color: petrol, bold: true);
      final summaryLine = summary.bundlesByItem.isEmpty
          ? 'لا توجد حجوزات نشطة لهذا اليوم'
          : summary.bundlesByItem.entries.map(
              (e) => '${e.key}: ${e.value} ربطة').join('   |   ');
      label(summaryLine, 747, 306, 690, size: 14,
        maxLines: 2);
    }
    label('تفاصيل الحجوزات', 749, 365, 680,
      size: 18, color: petrol, bold: true);
    fill(34,403,726,43,petrol);
    label('اسم العميل', 747, 414, 152, size: 13,
      color: white, bold: true);
    label('الهاتف', 586, 414, 117, size: 13,
      color: white, bold: true);
    label('الصنف', 458, 414, 132, size: 13,
      color: white, bold: true);
    label('الربطات', 314, 414, 59, size: 13,
      color: white, bold: true);
    label('الوقت', 248, 414, 72, size: 13,
      color: white, bold: true);
    label('الحالة', 166, 414, 125, size: 13,
      color: white, bold: true);

    if (rows.isEmpty) {
      label('لا توجد حجوزات في اليوم المحدد',
          744, 476, 660, size: 16, color: muted);
    }
    for (var i=0;i<rows.length;i++) {
      final reservation=rows[i];
      final y=451.0+i*29;
      if (i.isEven) fill(34,y,726,29,pale);
      label(reservation.customerName,747,y+6,152,size:11);
      label(reservation.phone.isEmpty ? '—' : reservation.phone,
          586,y+6,117,size:11);
      label(reservation.item,458,y+6,132,size:11);
      label('${reservation.bundles}',314,y+6,59,size:11,bold:true);
      label(reservation.pickupTime,248,y+6,72,size:11);
      label(reservation.status.label,166,y+6,125,size:10);
    }

    fill(34,1056,727,1,const ui.Color(0xFFDBE9EB));
    label('يُستخدم الكشف لمتابعة التجهيز فقط؛ '
      'ولا ينشئ ديناً أو حركة مالية.', 751,1065,705,
      size:12,color:muted);
    label('البيانات مخزنة مؤقتاً في الذاكرة وتختفي عند إعادة التشغيل.',
      751,1090,705,size:11,color:muted);

    final picture=recorder.endRecording();
    final image=await picture.toImage(
        (_width*scale).toInt(),(_height*scale).toInt());
    try {
      final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('PDF page rendering failed');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
