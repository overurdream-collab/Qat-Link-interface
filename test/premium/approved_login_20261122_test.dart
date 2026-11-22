import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/features/auth/registration_role.dart';
import 'package:qat_link/screens/login_screen.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/auth/auth_brand_hero.dart';

void main() {
  testWidgets('Owner-approved brand is blue 3D without a checkmark and uses every day a story',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(dark: false),
      home: const Scaffold(body: AuthBrandHero()),
    ));

    expect(find.byKey(const Key('approved_blue_3d_maqwati_wordmark')),
        findsOneWidget);
    expect(find.byKey(const Key('approved_login_tagline')), findsOneWidget);
    expect(find.text('كل يوم حكاية'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    expect(find.text('تعاملاتك بثقة وسهولة'), findsNothing);
  });

  testWidgets('Approved login keeps actual phone/PIN safety and expected controls',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(dark: false),
      home: LoginScreen(
        isDark: false,
        onToggleTheme: () {},
        onGenderChanged: (ProfileGender _) {},
        onOpenCustomerPreview: () {},
        onOpenMerchantPreview: () {},
      ),
    ));
    expect(find.text('العربية'), findsOneWidget);
    expect(find.byKey(const Key('login_phone')), findsOneWidget);
    expect(find.byKey(const Key('login_pin')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byKey(const Key('login_remember_me')), findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
    expect(find.text('خدمة العملاء'), findsOneWidget);
    expect(find.textContaining('GiC'), findsOneWidget);
    expect(find.text('كل يوم حكاية'), findsOneWidget);
    expect(find.text('Google'), findsNothing);
    expect(find.text('Apple'), findsNothing);
  });
}
