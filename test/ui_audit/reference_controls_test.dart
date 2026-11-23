import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/login_screen.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/theme/app_colors.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final pink in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('reference login controls pink=$pink dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = AppTheme.build(dark: dark, pink: pink);
        await tester.pumpWidget(MaterialApp(
            theme: theme,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: LoginScreen(
                isDark: dark,
                onToggleTheme: () {},
                onGenderChanged: (_) {},
                onOpenCustomerPreview: () {})));
        await tester.pumpAndSettle();
        final country =
            tester.widget<Text>(find.byKey(const Key('login_country_code')));
        expect(country.data, '+967');
        expect(country.textDirection, TextDirection.ltr);
        expect(
            tester.getCenter(find.byKey(const Key('login_remember_me'))).dx,
            greaterThan(tester
                .getCenter(find.byKey(const Key('login_forgot_password')))
                .dx));
        final field = tester.widget<TextField>(find.descendant(
            of: find.byKey(const Key('login_phone')),
            matching: find.byType(TextField)));
        // The field outline is UI information and must retain 3:1 contrast.
        final color = (field.decoration!.enabledBorder! as OutlineInputBorder)
            .borderSide
            .color;
        final surface = theme.extension<AppThemeColors>()!.card;
        final a = color.computeLuminance(), b = surface.computeLuminance();
        expect((a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05),
            greaterThanOrEqualTo(3));
        await tester.tap(find.byKey(const Key('login_language')));
        await tester.pumpAndSettle();
        expect(find.text('العربية'), findsNWidgets(2));
        await tester.tap(find.text('العربية').last);
        await tester.pumpAndSettle();
        expect(find.text('العربية'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('login_remember_me')));
        await tester.tap(find.byKey(const Key('login_remember_me')));
        await tester.pump();
        expect(
            tester
                .widget<Checkbox>(find.byKey(const Key('login_remember_me')))
                .value,
            isTrue);
        await tester.ensureVisible(find.byKey(const Key('login_submit')));
        await tester.tap(find.byKey(const Key('login_submit')));
        await tester.pumpAndSettle();
        expect(find.text('أدخل رقم الجوال'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('login_phone')));
        await tester.enterText(
            find.byKey(const Key('login_phone')), '771234567');
        await tester.pumpAndSettle();
        expect(find.text('أدخل رقم الجوال'), findsNothing);
        await tester.ensureVisible(find.byKey(const Key('login_pin')));
        await tester.enterText(find.byKey(const Key('login_pin')), '1234');
        await tester.pumpAndSettle();
        expect(
            tester
                .state<FormFieldState<String>>(
                    find.byKey(const Key('login_pin')))
                .hasError,
            isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
