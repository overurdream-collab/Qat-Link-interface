import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/merchant_shell_test_app.dart';
import 'package:qat_link/theme/app_colors.dart';

void main() {
  test('Yemen Modern Fintech daylight tokens are exact', () {
    expect(AppColors.petrol, const Color(0xFF07575B));
    expect(AppColors.mint, const Color(0xFF168E94));
    expect(AppColors.cyan, const Color(0xFF63B5C2));
    expect(AppColors.sea, const Color(0xFF438DB2));
    expect(AppColors.background, const Color(0xFFF4F9F8));
    expect(AppColors.card, const Color(0xFFFFFFFF));
    expect(AppColors.cardBorder, const Color(0xFFD8E7E5));
    expect(AppColors.pale, const Color(0xFFE3F3F0));
  });

  test('approved night colors are exact', () {
    expect(AppColors.darkPetrol, const Color(0xFFA2ECE2));
    expect(AppColors.darkBackground, const Color(0xFF13212D));
    expect(AppColors.darkCard, const Color(0xFF1D3140));
    expect(AppColors.darkBorder, const Color(0xFF355060));
    expect(AppColors.darkInk, const Color(0xFFEAF5FA));
  });

  test('hero and currency gradients match the Yemen Modern Fintech palette', () {
    expect(AppGradients.hero.colors, const [
      Color(0xFF07575B), Color(0xFF168E94), Color(0xFFB4E2DE),
    ]);
    expect(AppGradients.yer.colors, const [
      Color(0xFF07575B), Color(0xFF168E94), Color(0xFF438DB2),
    ]);
    expect(AppGradients.sar.colors, const [
      Color(0xFF07575B), Color(0xFF63B5C2), Color(0xFF168E94),
    ]);
  });

  testWidgets('shared chrome has the five approved tabs and top buttons', (tester) async {
    await tester.pumpWidget(const MerchantShellTestApp());
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('الحركة'), findsOneWidget);
    expect(find.text('العملاء'), findsOneWidget);
    expect(find.text('مساحتي'), findsOneWidget);
    expect(find.byTooltip('إضافة سريعة'), findsOneWidget);
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
