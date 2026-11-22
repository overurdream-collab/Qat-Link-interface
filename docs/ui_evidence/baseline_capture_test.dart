// Historical screenshot capture only, not an acceptance test suite.
// The acceptance matrix on the development branch is unchanged.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/login_screen.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final pink in [false, true]) {
    for (final dark in [false, true]) {
      for (final width in <double>[320, 360, 390, 430, 600, 800]) {
        final name = '${pink ? 'pink' : 'blue'}_${dark ? 'night' : 'day'}_${width.toInt()}';
        testWidgets('historical screenshot $name', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.build(dark: dark, pink: pink),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: RepaintBoundary(key: const Key('historical'), child: LoginScreen(
              isDark: dark, onToggleTheme: () {}, onGenderChanged: (_) {},
              onOpenCustomerPreview: () {})),
          ));
          await tester.pumpAndSettle();
          await expectLater(find.byKey(const Key('historical')),
            matchesGoldenFile('baseline_images/login_$name.png'));
        });
      }
    }
  }
}
