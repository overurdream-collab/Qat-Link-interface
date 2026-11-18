import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/widgets/auth/auth_brand_hero.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('approved offline brand artwork is bundled with Flutter', () async {
    final bg = await rootBundle.load(MaqwatiBrandAssets.loginBackground);
    final logo = await rootBundle.load(MaqwatiBrandAssets.horizontalLogo);
    expect(bg.lengthInBytes, greaterThan(2000));
    expect(logo.lengthInBytes, greaterThan(2000));
  });

  test('brand colors match turquoise and gold, financial tokens stay intact', () {
    expect(MaqwatiBrandColors.deepTeal, const Color(0xFF07575B));
    expect(MaqwatiBrandColors.turquoise, const Color(0xFF168E94));
    expect(MaqwatiBrandColors.gold, const Color(0xFFD4A13E));
  });

  testWidgets('brand header loads offline logo and accessible subtitle', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: AuthBrandHero()),
    ));
    expect(find.byKey(const Key('maqwati_branded_header')), findsOneWidget);
    expect(find.byKey(const Key('maqwati_horizontal_logo')), findsOneWidget);
    expect(find.text('مساعدك المالي الذكي'), findsOneWidget);
  });
}
