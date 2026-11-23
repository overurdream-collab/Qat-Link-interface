import 'image_audit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/login_screen.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/premium_tokens.dart';
import 'package:qat_link/widgets/home/premium_home_hero.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await loader.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final pink in [false, true]) {
    for (final dark in [false, true]) {
      final name = '${pink ? 'pink' : 'blue'}_${dark ? 'night' : 'day'}';
      final theme = AppTheme.build(dark: dark, pink: pink);
      final colors = theme.extension<AppThemeColors>()!;
      final visual = theme.extension<PremiumVisualPalette>()!;
      double contrast(Color a, Color b) {
        final x = a.computeLuminance();
        final y = b.computeLuminance();
        return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
      }

      test('$name body and secondary text contrast', () {
        expect(contrast(colors.text, colors.pale), greaterThanOrEqualTo(4.5));
        for (final status in [
          colors.success,
          colors.danger,
          colors.pendingText
        ]) {
          expect(contrast(status, colors.card), greaterThanOrEqualTo(4.5));
        }

        for (final stop in visual.accessibleAction.colors) {
          expect(contrast(Colors.white, stop), greaterThanOrEqualTo(4.5));
        }
        for (final stop in [
          visual.action,
          visual.hero,
          visual.yer,
          visual.sar,
          visual.usd
        ].expand((g) => visual.forWhiteText(g).colors)) {
          expect(contrast(Colors.white, stop), greaterThanOrEqualTo(4.5));
        }
        for (final foreground in [colors.text, colors.muted, colors.link]) {
          for (final surface in [colors.card, colors.background]) {
            expect(contrast(foreground, surface), greaterThanOrEqualTo(4.5));
          }
        }
        for (final foreground in [visual.ink, visual.muted]) {
          for (final stop in visual.canvas.colors) {
            expect(contrast(foreground, stop), greaterThanOrEqualTo(4.5));
          }
        }
      });
      testWidgets('$name home uses the decodable correct character',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
            theme: theme, home: const Scaffold(body: PremiumHomeHero())));
        final image = tester.widget<Image>(find.byType(Image));
        final provider = image.image is ResizeImage
            ? (image.image as ResizeImage).imageProvider
            : image.image;
        expect((provider as AssetImage).assetName, visual.characterAsset);
        expect(image.errorBuilder, isNull);
        await tester.pumpAndSettle();
        await auditDecodedImages(tester);
        expect(tester.takeException(), isNull);
      });
      for (final width in <double>[320, 360, 390, 430, 600, 800]) {
        for (final stress in [false, true]) {
          testWidgets(
              '$name $width ${stress ? 'keyboard_large_text' : 'baseline'}',
              (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, stress ? 640 : 900);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            await tester.pumpWidget(MaterialApp(
              theme: theme,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(stress ? 1.6 : 1),
                      viewInsets: EdgeInsets.only(bottom: stress ? 260 : 0)),
                  child: child!),
              home: RepaintBoundary(
                  key: const Key('capture'),
                  child: LoginScreen(
                      isDark: dark,
                      onToggleTheme: () {},
                      onGenderChanged: (_) {},
                      onOpenCustomerPreview: () {})),
            ));
            await tester.pumpAndSettle();
            await auditDecodedImages(tester);
            expect(
                tester
                    .getRect(find
                        .byKey(const Key('approved_blue_3d_maqwati_wordmark')))
                    .overlaps(tester
                        .getRect(find.byKey(const Key('login_language')))),
                isFalse,
                reason: 'The logo must remain clear of the language control');
            if (!stress) {
              await expectLater(
                  find.byKey(const Key('capture')),
                  matchesGoldenFile(
                      'goldens/login_${name}_${width.toInt()}.png'));
            }
            await tester.ensureVisible(find.byKey(const Key('login_submit')));
            await tester.tap(find.byKey(const Key('login_submit')));
            await tester.pumpAndSettle();
            await auditDecodedImages(tester);
            expect(tester.takeException(), isNull);
            await tester
                .ensureVisible(find.byKey(const Key('login_customer_support')));
            await tester.pumpAndSettle();
            await auditDecodedImages(tester);
            expect(tester.takeException(), isNull);
            expect(
                find.byKey(const Key('open_customer_preview')), findsNothing);
          });
        }
      }
    }
  }
}
