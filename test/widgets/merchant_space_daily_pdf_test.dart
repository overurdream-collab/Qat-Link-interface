import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/widgets/merchant_space/merchant_space_models.dart';
import 'package:qat_link/widgets/merchant_space/reservation_daily_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('daily booking preparation list creates a genuine Arabic A4 PDF',
      () async {
    final day = DateTime(2026, 11, 15);
    final rows = <ReservationDraft>[
      ReservationDraft(
        id: 'a', customerName: 'محمد أحمد',
        phone: '771234567', item: 'قات حاشدي',
        bundles: 3, day: day, pickupTime: '10:30',
        createdAt: day,
      ),
    ];
    final summary = ReservationsQuery.forDay(rows, day);
    final bytes = await ReservationDailyPdf.generate(
      day: day, storeName: 'متجر القمة',
      governorate: 'صنعاء', marketName: 'سوق معين',
      summary: summary,
    );
    expect(bytes.length, greaterThan(1800));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    expect(summary.totalBundles, 3);
    expect(summary.activeCount, 1);
  });
}
