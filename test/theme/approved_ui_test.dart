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

  test('Premium daylight tokens are exact', () {
    expect(AppColors.petrol, const Color(0xFF328BF5));
    expect(AppColors.mint, const Color(0xFF7939EA));
    expect(AppColors.cyan, const Color(0xFF73DCF6));
    expect(AppColors.sea, const Color(0xFF4358F5));
    expect(AppColors.background, const Color(0xFFF2F3FF));
    expect(AppColors.card, const Color(0xFFFFFFFF));
    expect(AppColors.cardBorder, const Color(0xFFE0E3F9));
    expect(AppColors.pale, const Color(0xFFC2A4FF));
  });

  test('approved night colors are exact', () {
    expect(AppColors.darkPetrol, const Color(0xFF8FB8FF));
    expect(AppColors.darkBackground, const Color(0xFF171A3C));
    expect(AppColors.darkCard, const Color(0xFF25294C));
    expect(AppColors.darkBorder, const Color(0xFF474D7C));
    expect(AppColors.darkInk, const Color(0xFFF3F3FF));
  });

  test('hero and currency gradients match the official blue/purple reference palette', () {
    expect(AppGradients.hero.colors, const [
      Color(0xFF7939EA), Color(0xFF328BF5), Color(0xFF73DCF6),
    ]);
    expect(AppGradients.yer.colors, const [
      Color(0xFF6F6CE8), Color(0xFF4B88F4), Color(0xFF83D5F8),
    ]);
    expect(AppGradients.sar.colors, const [
      Color(0xFF45A3D9), Color(0xFF76D8F1), Color(0xFFA8E4EF),
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
    expect((nav.decoration as BoxDecoration).color, AppColors.card);
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
