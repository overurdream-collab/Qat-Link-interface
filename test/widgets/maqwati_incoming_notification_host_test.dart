import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/widgets/notifications/maqwati_incoming_notification_host.dart';
import 'package:qat_link/widgets/notifications/maqwati_notifications_sheet.dart';

void main() {
  testWidgets('authenticated new event triggers peeking heads-up once',
      (tester) async {
    final event = MaqwatiNotificationEvent(
      id: 'real-event-001',
      title: 'وصل الحجز',
      message: 'تم تسليم الإشعار من نظام التنبيهات',
      category: 'حجوزات',
      receivedAt: DateTime(2026, 11, 19),
    );
    await tester.pumpWidget(const MaterialApp(home:
      MaqwatiIncomingNotificationHost(
        child: Scaffold(body: Text('الرئيسية')),
      )));
    expect(find.byKey(const Key('maqwati_heads_up')), findsNothing);

    await tester.pumpWidget(MaterialApp(home:
      MaqwatiIncomingNotificationHost(
        event: event,
        child: const Scaffold(body: Text('الرئيسية')),
      )));
    await tester.pump();
    expect(find.byKey(const Key('maqwati_heads_up')), findsOneWidget);
    expect(find.text('وصل الحجز'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}
