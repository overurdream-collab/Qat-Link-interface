import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main.dart';

void main() {
  testWidgets(
    'movement screen retains approved global header and bottom navigation',
    (tester) async {
      await tester.pumpWidget(const QatLinkApp());
      await tester.tap(find.text('الحركة'));
      await tester.pumpAndSettle();

      expect(find.text('سجل الحركة'), findsOneWidget);
      expect(find.text('جميع تعاملاتك المالية'), findsOneWidget);
      expect(find.text('إجمالي الحركة للفترة المحددة'), findsOneWidget);
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
      await tester.pumpWidget(const QatLinkApp());
      await tester.tap(find.text('الحركة'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('الوضع الليلي'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('الوضع النهاري'), findsOneWidget);

      await tester.tap(find.text('إصدار التقرير'));
      await tester.pumpAndSettle();
      expect(find.text('التصدير إلى PDF غير متصل بعد بخدمة التقارير.'),
          findsOneWidget);
    },
  );
}
