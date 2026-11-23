import '../helpers/brand_artwork_expectations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/theme/premium_tokens.dart';
import 'package:qat_link/widgets/auth/auth_brand_hero.dart';
import 'package:qat_link/widgets/home/new_currency_card.dart';

void main() {
  for (final feminine in <bool>[false, true]) {
    for (final dark in <bool>[false, true]) {
      final name = '${feminine ? 'pink' : 'blue'} ${dark ? 'dark' : 'light'}';
      final palette = PremiumVisualPalette.select(pink: feminine, dark: dark);

      testWidgets('$name uses an active premium palette on the brand header',
          (tester) async {
        late PremiumVisualPalette actual;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(dark: dark, pink: feminine),
          home: Scaffold(
            body: Builder(builder: (context) {
              actual = context.premium;
              return const SizedBox(height: 250, child: AuthBrandHero());
            }),
          ),
        ));
        expect(actual.accent, palette.accent);
        expect(find.byKey(const Key('approved_blue_3d_maqwati_wordmark')),
            findsOneWidget);
        expectApprovedBrandArtwork(tester);
        expect(tester.takeException(), isNull);
      });

      for (final currency in CurrencyCode.values) {
        testWidgets(
            '$name applies its own ${currency.name.toUpperCase()} gradient',
            (tester) async {
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.build(dark: dark, pink: feminine),
            home: Scaffold(
              body: Center(
                  child: SizedBox(
                height: 230,
                width: 340,
                child: NewCurrencyCard(
                    data: CurrencyCardData(
                  currency: currency,
                  debts: '100',
                  payments: '30',
                  pending: '20',
                  balance: '70',
                  collectionRate: .3,
                )),
              )),
            ),
          ));
          final card = tester.widget<Container>(
            find
                .descendant(
                    of: find.byType(NewCurrencyCard),
                    matching: find.byType(Container))
                .first,
          );
          final gradient =
              (card.decoration! as BoxDecoration).gradient! as LinearGradient;
          final expected = switch (currency) {
            CurrencyCode.yer => palette.yer,
            CurrencyCode.sar => palette.sar,
            CurrencyCode.usd => palette.usd,
          };
          expect(gradient.colors, palette.forWhiteText(expected).colors);
          expect(find.text('70'), findsOneWidget);
          expect(find.text('20'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
