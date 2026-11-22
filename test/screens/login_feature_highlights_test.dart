import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/theme/premium_tokens.dart';
import 'package:qat_link/widgets/auth/login_feature_highlights.dart';

void main() {
  const labels = <String>['دفتر حسابات', 'استوديو', 'حجوزات', 'مؤشرات مالية'];
  const keys = <String>['ledger', 'studio', 'bookings', 'insights'];

  for (final pink in <bool>[false, true]) {
    for (final dark in <bool>[false, true]) {
      for (final width in <double>[320, 390, 430]) {
        testWidgets('compact login highlights fit pink=$pink dark=$dark width=$width',
            (tester) async {
          tester.view.physicalSize = Size(width, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final palette = PremiumVisualPalette.select(pink: pink, dark: dark);
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.build(dark: dark, pink: pink),
            home: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: const [
                      LoginFeatureHighlights(),
                    ],
                  ),
                ),
              ),
            ),
          ));

          expect(find.byKey(const Key('login_feature_highlights')), findsOneWidget);
          for (var i = 0; i < keys.length; i++) {
            expect(find.byKey(Key('login_feature_${keys[i]}')), findsOneWidget);
            expect(find.text(labels[i]), findsOneWidget);
            final icon = tester.widget<Icon>(
                find.byKey(Key('login_feature_icon_${keys[i]}')));
            expect(icon.size, 23);
            expect(icon.color, palette.accent);
            final tile = tester.getSize(find.byKey(Key('login_feature_${keys[i]}')));
            expect(tile.height, 83);
            expect(tile.width, lessThan(95));
          }
          final first = tester.getTopLeft(find.byKey(const Key('login_feature_ledger')));
          final last = tester.getTopLeft(find.byKey(const Key('login_feature_insights')));
          expect(first.dx, greaterThan(last.dx)); // RTL ordering
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
