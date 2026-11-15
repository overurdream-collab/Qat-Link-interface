import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/screens/merchant_bookings_screen.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('merchant selects reminder audience and sees no invented reads',
      (tester) async {
    final state=AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      theme:AppTheme.light,
      home:Scaffold(body:MerchantBookingsScreen(
        state:state,bookings:const [],
        day:DateTime(2026,11,15),
        merchantId:'merchant1',
        storeName:'متجر التاجر',
        onDayChanged:(_){},onAddBooking:(){},
        onUpdateBooking:(_,__){},onBack:(){},
      )),
    ));
    await tester.scrollUntilVisible(
      find.byKey(const Key('reminder_audience')), 260,
      scrollable:find.byType(Scrollable).first);
    expect(find.byKey(const Key('reminder_audience')),findsOneWidget);
    expect(find.text('كل العملاء'),findsWidgets);
    await tester.tap(find.byKey(const Key('reminder_audience')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العملاء المفضلون').last);
    await tester.pumpAndSettle();
    expect(find.text('العملاء المفضلون'),findsOneWidget);
    expect(find.text('المستهدفون المسموح لهم: 0'),findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('تفاعل العملاء مع التذكير'),250,
      scrollable:find.byType(Scrollable).first);
    expect(find.text('تفاعل العملاء مع التذكير'),findsOneWidget);
    expect(find.textContaining('لا تتوفر إحصاءات فعلية'),findsOneWidget);
    expect(state.movements.value,isEmpty);
  });
}
