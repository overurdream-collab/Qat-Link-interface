import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/theme/premium_tokens.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Blue theme uses the blue mascot (dark: $dark)', (tester) async {
      late String asset;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(dark: dark, pink: false),
        home: Builder(builder: (context) {
          asset = context.maqwatiMascotAsset;
          return const Scaffold(body: Text('مقوتي'));
        }),
      ));
      expect(asset, 'assets/images/maqwati_mascot_blue.png');
    });

    testWidgets('Pink theme uses the rose mascot (dark: $dark)', (tester) async {
      late String asset;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(dark: dark, pink: true),
        home: Builder(builder: (context) {
          asset = context.maqwatiMascotAsset;
          return const Scaffold(body: Text('مقوتي'));
        }),
      ));
      expect(asset, 'assets/images/maqwati_mascot_pink.png');
    });
  }
}
