import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/premium_tokens.dart';

/// The authorized bitmap contains the printed name/tagline. Check the real
/// artwork and its accessible wording rather than requiring duplicate Text.
void expectApprovedBrandArtwork(WidgetTester tester) {
  final logoFinder = find.byKey(const Key('approved_blue_3d_maqwati_wordmark'));
  expect(logoFinder, findsOneWidget);
  final logo = tester.widget<Image>(logoFinder);
  final provider = logo.image is ResizeImage
      ? (logo.image as ResizeImage).imageProvider
      : logo.image;
  expect((provider as AssetImage).assetName, PremiumTokens.logoAsset);
  expect(logo.errorBuilder, isNull);
  expect(
    tester
        .widget<Semantics>(find.byKey(const Key('approved_login_tagline')))
        .properties
        .label,
    'كل يوم حكاية',
  );
  expect(
      find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.label == 'مقوتي لينك، كل يوم حكاية'),
      findsOneWidget);
}
