import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main_green_preview.dart' as green;
import 'package:qat_link/main_ui_preview.dart' show MaqwatiUiPreview;
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  test('the independent green concept matches its design tokens', () {
    expect(AppColors.petrol, const Color(0xFF176B24));
    expect(AppColors.mint, const Color(0xFF49B51B));
    expect(AppColors.pale, const Color(0xFFEDF9E8));
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
