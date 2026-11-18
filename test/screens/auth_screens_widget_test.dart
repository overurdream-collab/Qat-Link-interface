import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main.dart';

void main() {
  testWidgets('app opens login without exposing private finance tabs', (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
    expect(find.text('رقم الجوال اليمني'), findsOneWidget);
    expect(find.text('رمز الدخول'), findsOneWidget);
    expect(find.byKey(const Key('open_registration')), findsOneWidget);
    expect(find.text('الحركة'), findsNothing);
    expect(find.text('إجمالي الديون المعتمدة'), findsNothing);
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

  testWidgets('signup hands off only phone to OTP without creating account',
      (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.ensureVisible(find.byKey(const Key('open_registration')));
    await tester.tap(find.byKey(const Key('open_registration')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('register_name')),
        'محمد علي');
    await tester.enterText(find.byKey(const Key('register_phone')),
        '771234567');
    await tester.enterText(find.byKey(const Key('register_pin')), '1234');
    await tester.enterText(find.byKey(const Key('register_confirm_pin')),
        '1234');
    await tester.ensureVisible(find.byKey(const Key('register_submit')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pilot_url')), findsOneWidget);
    expect(find.byKey(const Key('pilot_phone')), findsOneWidget);
    final field = tester.widget<TextFormField>(
        find.byKey(const Key('pilot_phone')));
    expect(field.controller?.text, '+967771234567');
    expect(find.byKey(const Key('otp_request')), findsNothing);
    expect(find.text('الحركة'), findsNothing);
    expect(find.textContaining('تم إنشاء الحساب'), findsNothing);
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
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
    expect(find.textContaining('لا تُفتح الحسابات'), findsWidgets);
    expect(find.text('الحركة'), findsNothing);
  });

  testWidgets('debug OTP test requires manual HTTPS and never opens finance', (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.enterText(find.byKey(const Key('login_phone')), '776644312');
    await tester.ensureVisible(find.byKey(const Key('fin25_otp_test')));
    await tester.tap(find.byKey(const Key('fin25_otp_test')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin25_otp_server_url')), findsOneWidget);
    expect(find.byKey(const Key('otp_request')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('fin25_otp_server_url')), 'http://example.com');
    await tester.tap(find.byKey(const Key('fin25_otp_open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otp_request')), findsNothing);
    expect(find.text('الحركة'), findsNothing);
  });

  testWidgets('login supports the approved night theme', (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    expect(find.byTooltip('الوضع الليلي'), findsOneWidget);
    await tester.tap(find.byTooltip('الوضع الليلي'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('الوضع النهاري'), findsOneWidget);
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
  });
}
