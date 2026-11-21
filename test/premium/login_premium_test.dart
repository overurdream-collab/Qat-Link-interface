import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/login_screen.dart';
import 'package:qat_link/features/auth/registration_role.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('Premium login remains phone + PIN only and never authenticates locally', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(dark: false),
      home: LoginScreen(
        isDark: false,
        onToggleTheme: () {},
        onGenderChanged: (ProfileGender value) {},
        onOpenCustomerPreview: () {},
      ),
    ));

    expect(find.byKey(const Key('login_phone')), findsOneWidget);
    expect(find.byKey(const Key('login_pin')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.text('خدمة العملاء'), findsOneWidget);
    expect(find.textContaining('GiC'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('Google'), findsNothing);
    expect(find.text('Apple'), findsNothing);

    await tester.enterText(find.byKey(const Key('login_phone')), '771234567');
    await tester.enterText(find.byKey(const Key('login_pin')), '1234');
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.textContaining('غير متاح حتى توصيل المصادقة'), findsOneWidget);
  });
}
