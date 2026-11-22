import 'scroll_audit.dart';
import 'package:flutter/material.dart';
import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main.dart';
import 'package:qat_link/screens/customer_app_shell.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/app_chrome.dart';

// Exercise real widgets in their unauthenticated state. No fabricated session,
// backend response or financial balance is introduced into the application.
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
      for (final merchant in [true, false]) {
        final tabs = merchant ? [0, 1, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6];
        for (final width in <double>[320, 360, 390, 430, 600, 800]) {
          for (final scale in <double>[
            1,
            if (width == 320 || width == 390) 1.6
          ]) {
            for (final tab in tabs) {
              final id =
                  '${merchant ? 'merchant' : 'customer'}_${pink ? 'pink' : 'blue'}_${dark ? 'night' : 'day'}_${width.toInt()}_${scale}_$tab';
              testWidgets(
                  'role layout $id',
                  (tester) => withClock(Clock.fixed(DateTime(2026, 11, 22, 10)),
                          () async {
                        final handler = FlutterError.onError!;
                        FlutterError.onError = (details) {
                          debugPrint(details.toString());
                          handler(details);
                        };
                        addTearDown(() => FlutterError.onError = handler);
                        tester.view.devicePixelRatio = 1;
                        tester.view.physicalSize =
                            Size(width, scale > 1 ? 600 : 820);
                        addTearDown(tester.view.resetDevicePixelRatio);
                        addTearDown(tester.view.resetPhysicalSize);
                        await tester.pumpWidget(MaterialApp(
                          theme: AppTheme.build(dark: dark, pink: pink),
                          locale: const Locale('ar'),
                          supportedLocales: const [Locale('ar')],
                          localizationsDelegates:
                              GlobalMaterialLocalizations.delegates,
                          builder: (context, child) => RepaintBoundary(
                              key: const Key('role_capture'),
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                    textScaler: TextScaler.linear(scale)),
                                child: child!,
                              )),
                          home: RepaintBoundary(
                            child: merchant
                                ? MerchantAppShell(
                                    isDark: dark,
                                    isFemale: pink,
                                    isPinkTheme: pink,
                                    onToggleTheme: () {})
                                : CustomerAppShell(
                                    isDark: dark,
                                    onToggleTheme: () {},
                                    customerName:
                                        'حساب العميل ذو الاسم العربي الطويل جداً لمراجعة الاستجابة'),
                          ),
                        ));
                        await tester.pumpAndSettle();
                        if (tab >= 5) {
                          await tester.tap(
                              find.byTooltip(tab == 5 ? 'التنبيهات' : 'الضبط'));
                        } else if (merchant) {
                          const labels = {
                            0: 'الرئيسية',
                            1: 'الحركة',
                            3: 'العملاء',
                            4: 'مساحتي'
                          };
                          await tester.tap(find.descendant(
                              of: find.byType(AppBottomBar),
                              matching: find.text(labels[tab]!)));
                        } else {
                          await tester
                              .tap(find.byKey(Key('customer_nav_$tab')));
                        }
                        await tester.pumpAndSettle();
                        expect(tester.takeException(), isNull, reason: id);
                        if (scale == 1) {
                          await expectLater(
                              find.byKey(const Key('role_capture')),
                              matchesGoldenFile('goldens/roles/$id.png'));
                        }
                        await auditVerticalContent(tester);
                        if (scale == 1 && width == 390) {
                          await expectLater(
                              find.byKey(const Key('role_capture')),
                              matchesGoldenFile('goldens/scroll_end/$id.png'));
                        }
                        await tester.pumpWidget(const SizedBox.shrink());
                        await tester.pump();
                      }));
            }
          }
        }
      }
    }
  }
}
