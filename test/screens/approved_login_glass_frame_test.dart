import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/features/auth/registration_role.dart';
import 'package:qat_link/screens/login_screen.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/auth/auth_brand_hero.dart';

/// Visual acceptance contract for the owner's glass login reference.
/// This checks structure and absence of layout errors, not pixel-perfect art.
void main() {
  for (final female in <bool>[false, true]) {
    for (final dark in <bool>[false, true]) {
      for (final width in <double>[320, 390]) {
        testWidgets('approved login glass frame: female=$female dark=$dark width=$width',
            (tester) async {
          tester.view.physicalSize = Size(width, 820);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            locale: const Locale('ar'),
            theme: AppTheme.build(dark: dark, pink: female),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: LoginScreen(
                isDark: dark,
                onToggleTheme: () {},
                onGenderChanged: (ProfileGender gender) {},
                onOpenCustomerPreview: () {},
              ),
            ),
          ));
          expect(find.byKey(const Key('approved_glass_login_frame')),
              findsOneWidget);
          final frame = tester.widget<Container>(
              find.byKey(const Key('approved_glass_login_frame')));
          final decoration = frame.decoration! as BoxDecoration;
          expect(decoration.borderRadius, BorderRadius.circular(43));
          expect(find.byType(AuthBrandHero), findsOneWidget);
          expect(find.byKey(const Key('approved_login_tagline')), findsOneWidget);
          expect(find.byKey(const Key('login_phone')), findsOneWidget);
          expect(find.byKey(const Key('login_pin')), findsOneWidget);
          await tester.ensureVisible(find.byKey(const Key('login_submit')));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
