import '../helpers/brand_artwork_expectations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main_ui_preview.dart' show MaqwatiUiPreview;
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  test('the independent premium concept matches its design tokens', () {
    expect(AppColors.petrol, const Color(0xFF328BF5));
    expect(AppColors.mint, const Color(0xFF7939EA));
    expect(AppColors.pale, const Color(0xFFC2A4FF));
    expect(AppColors.ink, const Color(0xFF111A4B));
    expect(AppColors.muted, const Color(0xFF59638C));
    expect(AppColors.cardBorder, const Color(0xFFE0E3F9));
    expect(AppGradients.hero.colors, const [
      Color(0xFF7939EA),
      Color(0xFF328BF5),
      Color(0xFF73DCF6),
    ]);
    expect(
        AppTheme.build(dark: false).textTheme.bodyMedium?.fontFamily, 'Cairo');
    // Semantic ledger colors remain unchanged by the visual concept.
    expect(AppThemeColors.light.danger, AppColors.red);
    expect(AppThemeColors.pink.petrol, AppColors.pinkPrimary);
  });

  testWidgets('premium concept opens Arabic login with the mascot and tagline',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    expect(find.byKey(const Key('approved_blue_3d_maqwati_wordmark')),
        findsOneWidget);
    expectApprovedBrandArtwork(tester);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byKey(const Key('login_phone')), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, AppColors.petrol);
    expect(
        Directionality.of(
            tester.element(find.byKey(const Key('login_submit')))),
        TextDirection.rtl);
  });

  testWidgets('female profile still uses pink rather than forcing premium',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.byKey(const Key('preview_female_theme')));
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, AppColors.pinkPrimary);
    expect(app.theme!.extension<AppThemeColors>()!.danger, AppColors.red);
  });
}
