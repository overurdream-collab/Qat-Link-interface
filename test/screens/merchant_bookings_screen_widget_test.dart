import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/merchant_bookings_screen.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/merchant_space/merchant_space_models.dart';

void main() {
  late AppState state;
  setUp(() => state = AppState());
  tearDown(() => state.dispose());

  testWidgets('dedicated booking screen includes share, sales and debt preview',
      (tester) async {
    final day = DateTime(2026, 11, 15);
    final bookings = [
      ReservationDraft(
        id: 'b1', customerName: 'خالد علي', phone: '771234567',
        item: 'قات حاشدي', bundles: 3, pickupTime: '12:30',
        day: day, createdAt: day, status: ReservationStatus.collected,
        unitPrice: Decimal.parse('1500'), settlement: BookingSettlement.unpaid,
        currency: CurrencyCode.yer,
      ),
    ];
    var back = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: MerchantBookingsScreen(
        state: state, bookings: bookings,
        day: day, storeName: 'متجر التاجر',
        onDayChanged: (_) {}, onAddBooking: () {},
        onUpdateBooking: (_, __) {},
        onBack: () => back = true,
      )),
    ));
    expect(find.text('إدارة الحجوزات'), findsOneWidget);
    expect(find.byKey(const Key('workers_share_pdf')), findsOneWidget);
    expect(find.byKey(const Key('workers_print_pdf')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ديون اليوم'), 210,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('ديون اليوم'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('bookings_select_b1')), 220,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('bookings_select_b1')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('bookings_batch_debt')));
    await tester.tap(find.byKey(const Key('bookings_batch_debt')));
    await tester.pumpAndSettle();
    expect(find.text('مراجعة التحويل الجماعي إلى ديون'), findsOneWidget);
    expect(find.textContaining('غير متوفرة'), findsWidgets);
    expect(state.movements.value, isEmpty);
    await tester.tap(find.byKey(const Key('booking_batch_close')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('bookings_back_to_space')), -280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('bookings_back_to_space')));
    expect(back, true);
  });
}
