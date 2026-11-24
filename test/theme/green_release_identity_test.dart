import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/theme/premium_tokens.dart';

void main() {
  test('release base theme and latest shared screen palette use approved green', () {
    const approved = [Color(0xFF8AD15A), Color(0xFF6CC04A), Color(0xFF4EAD3D)];
    expect(AppGradients.hero.colors, approved);
    expect(PremiumTokens.action.colors, approved);
    expect(PremiumVisualPalette.premium.hero.colors, approved);
    expect(PremiumVisualPalette.premium.accent, const Color(0xFF2E7D32));
    for (final dark in [false, true]) {
      final theme = AppTheme.build(dark: dark);
      final palette = theme.extension<PremiumVisualPalette>()!;
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Cairo');
      expect(palette.action.colors, approved);
      expect(palette.yer.colors, AppGradients.yer.colors);
      expect(palette.sar.colors, AppGradients.sar.colors);
      expect(palette.usd.colors, AppGradients.usd.colors);
      expect(theme.colorScheme.primary,
          dark ? AppColors.darkPetrol : AppColors.petrol);
      expect(theme.extension<AppThemeColors>()!.danger,
          dark ? AppThemeColors.dark.danger : AppColors.red);
    }
    // The existing optional female theme remains separate from the base brand.
    final female = AppTheme.build(dark: false, pink: true);
    expect(female.extension<PremiumVisualPalette>(), PremiumVisualPalette.feminine);
    expect(female.colorScheme.primary, AppColors.pinkPrimary);
  });
}
