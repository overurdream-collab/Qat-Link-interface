import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  test('official brand tokens and separate currency gradients are exact', () {
    expect(AppColors.petrol, const Color(0xFF328BF5));
    expect(AppColors.mint, const Color(0xFF7939EA));
    expect(AppColors.background, const Color(0xFFF2F3FF));
    expect(AppColors.pinkPrimary, const Color(0xFFAD3379));
    expect(AppColors.pinkBackground, const Color(0xFFFFEFF6));
    expect(AppColors.darkBackground, const Color(0xFF171A3C));
    expect(AppThemeColors.pinkDark.background, const Color(0xFF251B30));
    expect(AppGradients.yer.colors,
      const [Color(0xFF6F6CE8), Color(0xFF4B88F4), Color(0xFF83D5F8)]);
    expect(AppGradients.sar.colors,
      const [Color(0xFF45A3D9), Color(0xFF76D8F1), Color(0xFFA8E4EF)]);
    expect(AppGradients.usd.colors,
      const [Color(0xFF7458D1), Color(0xFF997DF6), Color(0xFFB9A9F7)]);
    expect(AppGradients.pinkYer.colors,
      const [Color(0xFFA23478), Color(0xFFAC3E81), Color(0xFFB7468A)]);
    expect(AppGradients.pinkSar.colors,
      const [Color(0xFF963E77), Color(0xFFA74A82), Color(0xFFAD5388)]);
    expect(AppGradients.pinkUsd.colors,
      const [Color(0xFF69429D), Color(0xFF7D4BA8), Color(0xFF8B56B6)]);
    expect(AppGradients.forCurrency('YER', pink: true), AppGradients.pinkYer);
    expect(AppGradients.forCurrency('SAR'), AppGradients.sar);
    expect(AppGradients.forCurrency('USD', pink: true), AppGradients.pinkUsd);
    expect(() => AppGradients.forCurrency('EUR'), throwsArgumentError);
  });

  test('Cairo and all four theme backgrounds remain consistent', () {
    final blueDay = AppTheme.build(dark: false);
    final blueNight = AppTheme.build(dark: true);
    final pinkDay = AppTheme.build(dark: false, pink: true);
    final pinkNight = AppTheme.build(dark: true, pink: true);
    expect(blueDay.scaffoldBackgroundColor, const Color(0xFFF2F3FF));
    expect(blueNight.scaffoldBackgroundColor, const Color(0xFF171A3C));
    expect(pinkDay.scaffoldBackgroundColor, const Color(0xFFFFEFF6));
    expect(pinkNight.scaffoldBackgroundColor, const Color(0xFF251B30));
    for (final theme in [blueDay, blueNight, pinkDay, pinkNight]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Cairo');
      expect(theme.colorScheme.error, isNot(equals(Colors.transparent)));
    }
  });
}
