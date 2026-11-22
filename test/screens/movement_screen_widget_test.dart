import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../helpers/merchant_shell_test_app.dart';

void main() {
  testWidgets(
    'movement screen retains approved global header and bottom navigation',
    (tester) async {
      await tester.pumpWidget(const MerchantShellTestApp());
      await tester.tap(find.text('الحركة'));
      await tester.pumpAndSettle();

      expect(find.text('سجل الحركة'), findsOneWidget);
      expect(find.text('جميع تعاملاتك المالية'), findsOneWidget);
      expect(find.text('إجمالي الحركة للفترة المحددة'), findsOneWidget);
      await _revealReport(tester);
      expect(find.text('كشف الحركة'), findsOneWidget);

      expect(find.byTooltip('الضبط'), findsOneWidget);
      expect(find.byTooltip('التنبيهات'), findsOneWidget);
      expect(find.byTooltip('الوضع الليلي'), findsOneWidget);
      expect(find.byTooltip('إضافة سريعة'), findsOneWidget);

      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('العملاء'), findsOneWidget);
      expect(find.text('مساحتي'), findsOneWidget);
    },
  );

  testWidgets(
    'movement tab keeps theme toggle and opens the report preview',
    (tester) async {
      await tester.pumpWidget(const MerchantShellTestApp());
      await tester.tap(find.text('الحركة'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('الوضع الليلي'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('الوضع النهاري'), findsOneWidget);

      await _revealReport(tester);
      await tester.tap(find.text('إصدار التقرير'));
      await tester.pumpAndSettle();
      expect(find.text('التصدير إلى PDF غير متصل بعد بخدمة التقارير.'),
          findsOneWidget);
    },
  );
}

Future<void> _revealReport(WidgetTester tester) async {
  final scrollable = find
      .byWidgetPredicate((widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down)
      .hitTestable()
      .first;
  await tester.scrollUntilVisible(find.text('إصدار التقرير'), 250,
      scrollable: scrollable);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
