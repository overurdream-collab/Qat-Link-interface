import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main_ui_preview.dart' show MaqwatiUiPreview;
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  test('the independent green concept matches its design tokens', () {
    expect(AppColors.petrol, const Color(0xFF2E7D32));
    expect(AppColors.mint, const Color(0xFF6CC04A));
    expect(AppColors.pale, const Color(0xFFEDF9E8));
    expect(AppColors.ink, const Color(0xFF1F2937));
    expect(AppColors.muted, const Color(0xFF6B7280));
    expect(AppColors.cardBorder, const Color(0xFFE5E7EB));
    expect(AppGradients.hero.colors, const [
      Color(0xFF8AD15A), Color(0xFF6CC04A), Color(0xFF4EAD3D),
    ]);
    expect(AppTheme.build(dark: false).textTheme.bodyMedium?.fontFamily, 'Cairo');
    // Semantic ledger colors remain unchanged by the visual concept.
    expect(AppThemeColors.light.danger, AppColors.red);
    expect(AppThemeColors.pink.petrol, AppColors.pinkPrimary);
  });

  testWidgets('green concept opens Arabic login with the mascot and tagline',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    expect(find.text('مقوتي لينك'), findsOneWidget);
    expect(find.text('حلقة وصل بينك وبين عملائك'), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byIcon(Icons.spa_rounded), findsWidgets);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, AppColors.petrol);
    expect(Directionality.of(tester.element(find.byKey(const Key('login_submit')))),
        TextDirection.rtl);
  });

  testWidgets('female profile still uses pink rather than forcing green',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.byKey(const Key('preview_female_theme')));
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, AppColors.pinkPrimary);
    expect(app.theme!.extension<AppThemeColors>()!.danger, AppColors.red);
  });
}
