import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  group('HTML reference palette is preserved verbatim', () {
    test('brand colors', () {
      expect(AppColors.blue, const Color(0xFF3A70D2));
      expect(AppColors.blueLight, const Color(0xFF497CD7));
      expect(AppColors.blueMid, const Color(0xFF5A94DD));
      expect(AppColors.sky, const Color(0xFF7FBDEC));
      expect(AppColors.cyan, const Color(0xFFA4E6F2));
      expect(AppColors.mint, const Color(0xFFB0E9DA));
      expect(AppColors.green, const Color(0xFFCDEABE));
      expect(AppColors.lime, const Color(0xFFD5ECA6));
      expect(AppColors.iconGreen, const Color(0xFFA5E8A1));
      expect(AppColors.button, const Color(0xFF3868C8));
      expect(AppColors.navy, const Color(0xFF0A0D3B));
    });

    test('neutral and status-background colors', () {
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.section, const Color(0xFFF6F6F6));
      expect(AppColors.background, const Color(0xFFE5E8ED));
      expect(AppColors.muted, const Color(0xFF9DA5B8));
      expect(AppColors.redBackground, const Color(0xFFF8D9DD));
    });

    test('source gradient stops', () {
      expect(AppGradients.header.stops, [0.03, 0.45, 0.80, 1.0]);
      expect(AppGradients.header.colors, [
        const Color(0xFF497CD7),
        const Color(0xFF76B7E7),
        const Color(0xFFA4DCCE),
        const Color(0xFFCDEABE),
      ]);
      expect(AppGradients.balance.stops, [0.0, 0.52, 1.0]);
      expect(AppGradients.balance.colors, [
        const Color(0xFF3A70D2),
        const Color(0xFF5189DD),
        const Color(0xFF89D0EC),
      ]);
    });

    test('light theme maps tokens to Material components', () {
      expect(AppTheme.light.colorScheme.primary, AppColors.button);
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.section);
      expect(AppTheme.light.colorScheme.onSurface, AppColors.navy);
    });
  });
}
