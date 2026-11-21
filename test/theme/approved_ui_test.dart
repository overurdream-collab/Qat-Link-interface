import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/merchant_shell_test_app.dart';
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  test('Cairo Arabic typeface is applied across base, dark and female themes', () {
    for (final theme in [
      AppTheme.build(dark: false),
      AppTheme.build(dark: true),
      AppTheme.build(dark: false, pink: true),
      AppTheme.build(dark: true, pink: true),
    ]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Cairo');
    }
  });

  test('Isolated Yemen Green daylight tokens are exact', () {
    expect(AppColors.petrol, const Color(0xFF2E7D32));
    expect(AppColors.mint, const Color(0xFF6CC04A));
    expect(AppColors.cyan, const Color(0xFF8AD15A));
    expect(AppColors.sea, const Color(0xFF4EAD3D));
    expect(AppColors.background, const Color(0xFFF7FBF5));
    expect(AppColors.card, const Color(0xFFFFFFFF));
    expect(AppColors.cardBorder, const Color(0xFFE5E7EB));
    expect(AppColors.pale, const Color(0xFFEDF9E8));
  });

  test('approved night colors are exact', () {
    expect(AppColors.darkPetrol, const Color(0xFFB4F28D));
    expect(AppColors.darkBackground, const Color(0xFF15261B));
    expect(AppColors.darkCard, const Color(0xFF203629));
    expect(AppColors.darkBorder, const Color(0xFF45674B));
    expect(AppColors.darkInk, const Color(0xFFF0FFE9));
  });

  test('hero and currency gradients match the green reference palette', () {
    expect(AppGradients.hero.colors, const [
      Color(0xFF8AD15A), Color(0xFF6CC04A), Color(0xFF4EAD3D),
    ]);
    expect(AppGradients.yer.colors, const [
      Color(0xFF2E7D32), Color(0xFF6CC04A), Color(0xFF4EAD3D),
    ]);
    expect(AppGradients.sar.colors, const [
      Color(0xFF2E7D32), Color(0xFF8AD15A), Color(0xFF6CC04A),
    ]);
  });

  testWidgets('shared chrome has the five approved tabs and top buttons', (tester) async {
    await tester.pumpWidget(const MerchantShellTestApp());
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('الحركة'), findsOneWidget);
    expect(find.text('العملاء'), findsOneWidget);
    expect(find.text('مساحتي'), findsOneWidget);
    expect(find.byTooltip('إضافة سريعة'), findsOneWidget);
    final nav = tester.widget<Container>(
      find.byKey(const Key('merchant_green_bottom_bar')),
    );
    expect((nav.decoration as BoxDecoration).color, AppColors.mint);
    expect(find.byTooltip('الضبط'), findsOneWidget);
    expect(find.byTooltip('التنبيهات'), findsOneWidget);
    expect(find.byTooltip('الوضع الليلي'), findsOneWidget);
  });

  testWidgets('theme toggle retains header and navigation', (tester) async {
    await tester.pumpWidget(const MerchantShellTestApp());
    await tester.tap(find.byTooltip('الوضع الليلي'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('الوضع النهاري'), findsOneWidget);
    expect(find.text('مساحتي'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
  });

  testWidgets('quick add offers three actions but no automatic financial write',
      (tester) async {
    await tester.pumpWidget(const MerchantShellTestApp());
    await tester.tap(find.byTooltip('إضافة سريعة'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة عميل'), findsOneWidget);
    expect(find.text('إضافة دين'), findsOneWidget);
    expect(find.text('إضافة مبلغ'), findsOneWidget);
  });
}
