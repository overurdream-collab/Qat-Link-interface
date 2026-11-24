import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/customer_updates_screen.dart';
import 'package:qat_link/widgets/notifications/maqwati_notifications_sheet.dart';

void main() {
  testWidgets('customer bookings are separate from financial approval',
      (tester) async {
    final booking = CustomerUpdate(
      event: MaqwatiNotificationEvent(
        id:'b-1',
        category:'حجز',
        title:'حجز بانتظار الاستلام',
        message:'موعد التسليم حسب التاجر',
        receivedAt:DateTime(2026,11,19),
      ),
      category:CustomerUpdateCategory.bookings,
      bookingStatus:'معلق',
    );
    final notice= CustomerUpdate(
      event:MaqwatiNotificationEvent(
        id:'n-1',category:'إشعار',
        title:'تنبيه من المتجر',
        message:'تم تحديث أوقات العمل',
        receivedAt:DateTime(2026,11,19),
      ),
      category:CustomerUpdateCategory.notifications,
    );
    await tester.pumpWidget(MaterialApp(home:CustomerUpdatesScreen(
      updates:[booking,notice],
    )));
    expect(find.text('تنبيه من المتجر'), findsOneWidget);
    expect(find.text('حجز بانتظار الاستلام'), findsNothing);
    await tester.tap(find.byKey(const Key('customer_tab_bookings')));
    await tester.pumpAndSettle();
    expect(find.text('حجز بانتظار الاستلام'), findsOneWidget);
    expect(find.text('تنبيه من المتجر'), findsNothing);
    expect(find.textContaining('لا يصبح أي مبلغ ديناً معتمداً'),
        findsOneWidget);
  });

  testWidgets('empty customer inbox shows no synthetic bookings',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:CustomerUpdatesScreen()));
    await tester.tap(find.byKey(const Key('customer_tab_bookings')));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد حجوزات موثّقة لعرضها.'), findsOneWidget);
    expect(find.byKey(const Key('maqwati_arrival_card')), findsNothing);
  });
}
