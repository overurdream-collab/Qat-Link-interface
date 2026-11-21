import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/main.dart';

void main() {
  testWidgets('app opens login without exposing private finance tabs', (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('رقم الجوال'), findsOneWidget);
    expect(find.text('رمز الدخول'), findsOneWidget);
    expect(find.byKey(const Key('open_registration')), findsOneWidget);
    expect(find.text('الحركة'), findsNothing);
    expect(find.text('إجمالي الديون المعتمدة'), findsNothing);
  });

  testWidgets('login opens only a clearly labeled customer UI preview',
      (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.ensureVisible(find.text('معاينة الواجهات التجريبية'));
    await tester.tap(find.text('معاينة الواجهات التجريبية'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('open_customer_preview')));
    await tester.tap(find.byKey(const Key('open_customer_preview')));
    await tester.pumpAndSettle();
    expect(find.textContaining('معاينة واجهات العميل'), findsOneWidget);
    expect(find.text('سجل الحركة'), findsNothing);
    expect(find.text('سجل الحساب خاص'), findsNothing);
    expect(find.byKey(const Key('home_campaign_carousel')), findsOneWidget);
    expect(find.textContaining('لا تعرض بيانات أو أرصدة حقيقية'), findsOneWidget);
  });

  testWidgets('registered role options stay on a separate page', (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.ensureVisible(find.byKey(const Key('open_registration')));
    await tester.tap(find.byKey(const Key('open_registration')));
    await tester.pumpAndSettle();
    expect(find.text('اختر فئة حسابك'), findsOneWidget);
    expect(find.text('عميل'), findsOneWidget);
    expect(find.text('تاجر'), findsOneWidget);
    expect(find.text('مورد'), findsOneWidget);
    await tester.tap(find.byKey(const Key('role_supplier')));
    await tester.pump();
    expect(find.text('أتواصل مع التجار وأنظم التوريدات'), findsOneWidget);
    await tester.tap(find.byKey(const Key('role_customer')));
    await tester.pump();
    expect(find.text('أتابع حساباتي وأراجع طلبات التجار'), findsOneWidget);
  });

  testWidgets('login form does not grant a session on valid local inputs', (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.enterText(
      find.byKey(const Key('login_phone')), '771234567');
    await tester.enterText(
      find.byKey(const Key('login_pin')), '1234');
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.textContaining('لا تُفتح الحسابات'), findsWidgets);
    expect(find.text('الحركة'), findsNothing);
  });

  testWidgets('login supports the approved night theme', (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    expect(find.byTooltip('الوضع الليلي'), findsOneWidget);
    await tester.tap(find.byTooltip('الوضع الليلي'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('الوضع النهاري'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });

  testWidgets('female registration selects pink identity and male restores base',
      (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.ensureVisible(find.byKey(const Key('open_registration')));
    await tester.tap(find.byKey(const Key('open_registration')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gender_female')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!
          .colorScheme.primary,
      AppColors.pinkPrimary,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!
          .scaffoldBackgroundColor,
      AppColors.pinkBackground,
    );

    await tester.tap(find.byKey(const Key('gender_male')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!
          .colorScheme.primary,
      AppColors.petrol,
    );
  });
}
