import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/widgets/merchant_space/merchant_space_models.dart';
import 'package:qat_link/widgets/merchant_space/worker_preparation_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('large-format workers report generates offline multipage A4 PDF', () async {
    final day = DateTime(2026, 11, 15);
    final orders = [
      for (var i = 0; i < 13; i++)
        ReservationDraft(
          id: 'order$i',
          customerName: 'عميل رقم $i',
          phone: '777123456',
          item: 'قات حاشدي',
          bundles: 2,
          pickupTime: '12:00',
          createdAt: day,
          day: day,
          status: ReservationStatus.preparing,
        ),
    ];
    final summary = ReservationsQuery.forDay(orders, day);
    final bytes = await WorkerPreparationPdf.generate(
      day: day, storeName: 'متجر القات', summary: summary);
    expect(bytes.length, greaterThan(2000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(summary.totalBundles, 26);
  });
}
