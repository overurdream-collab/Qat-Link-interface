import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/merchant_space_screen.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  late AppState state;
  setUp(() => state = AppState());
  tearDown(() => state.dispose());

  Future<void> pumpSpace(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: MerchantSpaceTab(state: state)),
    ));
  }

  testWidgets('store page has approved banner/status/address and booking CTA',
      (tester) async {
    await pumpSpace(tester);
    expect(find.text('مساحتي'), findsOneWidget);
    expect(find.byKey(const Key('store_open_toggle')), findsOneWidget);
    expect(find.text('مغلق'), findsOneWidget);
    expect(find.byKey(const Key('edit_store_location')), findsOneWidget);
    expect(find.text('حجوزات اليوم'), findsOneWidget);
    expect(find.byKey(const Key('booking_add_quick')), findsOneWidget);
    await tester.tap(find.byKey(const Key('store_open_toggle')));
    await tester.pump();
    expect(find.text('مفتوح'), findsOneWidget);
  });

  testWidgets('quick booking is a local operational draft, never a debt',
      (tester) async {
    await pumpSpace(tester);
    await tester.tap(find.byKey(const Key('booking_add_quick')));
    await tester.pumpAndSettle();
    expect(find.text('إضافة حجز سريع'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('booking_customer')), 'صالح حسن');
    await tester.enterText(
        find.byKey(const Key('booking_item')), 'قات حاشدي');
    await tester.enterText(
        find.byKey(const Key('booking_bundles')), '3');
    await tester.enterText(
        find.byKey(const Key('booking_pickup')), '14:30');
    await tester.ensureVisible(find.byKey(const Key('booking_save_draft')));
    await tester.tap(find.byKey(const Key('booking_save_draft')));
    await tester.pumpAndSettle();
    expect(find.text('صالح حسن'), findsOneWidget);
    expect(find.textContaining('3 ربطة'), findsWidgets);
    expect(state.movements.value, isEmpty);
    expect(state.relationships.value, isEmpty);
  });

  testWidgets('broadcast preview does not send or create financial entries',
      (tester) async {
    await pumpSpace(tester);
    await tester.scrollUntilVisible(
      find.text('تنبيهات العملاء'), 240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
        find.byKey(const Key('broadcast_message')),
        'بضاعة جديدة وصلت المتجر');
    await tester.ensureVisible(find.byKey(const Key('broadcast_review')));
    await tester.tap(find.byKey(const Key('broadcast_review')));
    await tester.pumpAndSettle();
    expect(find.text('مراجعة التنبيه'), findsOneWidget);
    expect(find.textContaining('لا يوجد إرسال فعلي'), findsOneWidget);
    expect(state.movements.value, isEmpty);
  });

  testWidgets('studio and engagement dashboard show no invented statistics',
      (tester) async {
    await pumpSpace(tester);
    await tester.scrollUntilVisible(find.text('استوديو التاجر'), 260,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('studio_add_photo')), findsOneWidget);
    expect(find.byKey(const Key('studio_add_video')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('تفاعل الجمهور'), 260,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('المشاهدات'), findsOneWidget);
    expect(find.text('الإعجابات'), findsOneWidget);
    expect(find.text('المشاركات'), findsOneWidget);
  });
}
