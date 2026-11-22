import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/home/new_currency_card.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf')))
        .load();
  });
  for (final pink in [false, true]) {
    for (final dark in [false, true]) {
      for (final currency in CurrencyCode.values) {
        for (final width in <double>[220, 320]) {
          for (final scale in <double>[1, 1.6]) {
            testWidgets(
                'long approved amount $pink $dark $currency $width $scale',
                (tester) async {
              const amount = '9,876,543,210,987,654,321.99';
              await tester.pumpWidget(MaterialApp(
                theme: AppTheme.build(dark: dark, pink: pink),
                home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Scaffold(
                            body: Center(
                                child: SizedBox(
                                    width: width,
                                    height: 230 * scale,
                                    child: NewCurrencyCard(
                                        data: CurrencyCardData(
                                            currency: currency,
                                            debts: amount,
                                            balance: amount,
                                            payments: '123,456,789.01',
                                            pending: '987,654,321.12',
                                            collectionRate: .34))))))),
              ));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final viewport = find
                  .ancestor(
                      of: find.text(amount),
                      matching: find.byType(SingleChildScrollView))
                  .first;
              final meter =
                  tester.getRect(find.byType(CircularProgressIndicator));
              expect(tester.getRect(viewport).overlaps(meter), isFalse,
                  reason:
                      'The amount viewport must not overlap the collection indicator');
              final scrolling = find.descendant(
                  of: viewport, matching: find.byType(Scrollable));
              expect(
                  tester
                      .state<ScrollableState>(scrolling)
                      .position
                      .maxScrollExtent,
                  greaterThan(0));
              await tester.drag(viewport, const Offset(140, 0));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(find.text(amount), findsOneWidget);
            });
          }
        }
      }
    }
  }
}
