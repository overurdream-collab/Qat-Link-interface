import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main.dart';
import 'package:qat_link/screens/notification_design_preview_screen.dart';

void main() {
  testWidgets('debug login opens local preview without granting a session',
      (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.ensureVisible(
      find.byKey(const Key('open_notification_design_preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_notification_design_preview')));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationDesignPreviewScreen), findsOneWidget);
    expect(find.byKey(const Key('design_preview_disclaimer')), findsOneWidget);
    expect(find.textContaining('لم يُرسل أي SMS'), findsOneWidget);
    expect(find.text('تم تسجيل الدخول بنجاح'), findsNothing);

    await tester.tap(find.byKey(const Key('preview_incoming_booking')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('ظهر حجز جديد!'), findsOneWidget);
    expect(find.byKey(const Key('maqwati_heads_up')), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.tap(find.byKey(const Key('preview_incoming_notification')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('لديك إشعار جديد!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
