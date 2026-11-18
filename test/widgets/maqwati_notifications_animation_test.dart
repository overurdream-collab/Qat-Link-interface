import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/notifications/maqwati_notifications_sheet.dart';
import 'package:qat_link/widgets/notifications/maqwati_peeking_mascot.dart';

void main() {
  testWidgets('new booking card shows mascot and genuine event body',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: MaqwatiArrivalCard(
        title: 'حجز مؤكد للتجهيز',
        message: 'طلب تجريبي داخل الاختبار فقط',
        category: 'حجز',
        isNew: true,
      )),
    ));
    expect(find.byKey(const Key('maqwati_arrival_card')), findsOneWidget);
    expect(find.byKey(const Key('maqwati_mascot_peek')), findsOneWidget);
    expect(find.text('حجز مؤكد للتجهيز'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('honors reduced motion accessibility setting', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const Scaffold(body: MaqwatiPeekingMascot()),
      ),
    ));
    expect(find.byKey(const Key('maqwati_mascot_peek')), findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty notification inbox does not invent a received alert',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: MaqwatiNotificationsSheet()),
    ));
    expect(find.text('لا توجد تنبيهات متصلة بالخادم حالياً.'), findsOneWidget);
    expect(find.byKey(const Key('maqwati_arrival_card')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('preview_mascot_animation')));
    await tester.tap(find.byKey(const Key('preview_mascot_animation')));
    await tester.pump();
    expect(find.textContaining('لم يتم إرسال أي إشعار'), findsOneWidget);
    expect(find.byKey(const Key('maqwati_arrival_card')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('server-provided event appears with the official mascot',
      (tester) async {
    final now=DateTime.now();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: MaqwatiNotificationsSheet(events: [
        MaqwatiNotificationEvent(
          id: 'verified-123',
          category: 'حجز',
          title: 'تم استلام طلبك',
          message: 'بانتظار التأكيد',
          receivedAt: now,
        ),
      ])),
    ));
    expect(find.text('تم استلام طلبك'), findsOneWidget);
    expect(find.byKey(const Key('maqwati_mascot_peek')), findsOneWidget);
  });
}
