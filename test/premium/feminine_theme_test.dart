import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/theme/premium_tokens.dart';

void main() {
  testWidgets('Female light theme uses rose and orchid, not blue controls', (tester) async {
    late PremiumVisualPalette palette;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(dark: false, pink: true),
      home: Builder(builder: (context) {
        palette = context.premium;
        return const Scaffold(body: Text('مقوتي'));
      }),
    ));
    expect(palette.accent, const Color(0xFFAD3379));
    expect(palette.ink, const Color(0xFF45233D));
    expect(palette.hero.colors.first, const Color(0xFFB03F80));
    expect(palette.yer.colors.first, const Color(0xFFA23478));
    expect(palette.sar.colors.first, const Color(0xFF963E77));
    expect(palette.usd.colors.first, const Color(0xFF69429D));
    expect(find.text('مقوتي'), findsOneWidget);
  });

  testWidgets('Female night theme has its own readable rose-plum palette', (tester) async {
    late PremiumVisualPalette palette;
    late AppThemeColors financial;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(dark: true, pink: true),
      home: Builder(builder: (context) {
        palette = context.premium;
        financial = context.colors;
        return const Scaffold(body: Text('مقوتي'));
      }),
    ));
    expect(palette.surface, const Color(0xFF392B3D));
    expect(palette.ink, const Color(0xFFFFEFF7));
    expect(palette.accent, const Color(0xFFF2A7D0));
    expect(financial.success, AppColors.darkSuccess);
    expect(financial.pendingText, const Color(0xFFEFCA86));
  });

  test('Financial-status colors remain independent of female theme', () {
    expect(AppThemeColors.pink.success, AppThemeColors.light.success);
    expect(AppThemeColors.pink.danger, AppThemeColors.light.danger);
    expect(AppThemeColors.pink.pendingText, AppThemeColors.light.pendingText);
    expect(AppThemeColors.pinkDark.success, AppThemeColors.dark.success);
    expect(AppThemeColors.pinkDark.danger, AppThemeColors.dark.danger);
    expect(AppThemeColors.pinkDark.pendingText, AppThemeColors.dark.pendingText);
  });

  testWidgets('Non-female account retains original blue-violet palette', (tester) async {
    late PremiumVisualPalette palette;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(dark: false),
      home: Builder(builder: (context) {
        palette = context.premium;
        return const Scaffold(body: Text('مقوتي'));
      }),
    ));
    expect(palette.accent, PremiumTokens.violet);
    expect(palette.yer.colors.first, const Color(0xFF6F6CE8));
  });
}
