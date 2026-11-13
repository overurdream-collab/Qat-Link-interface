import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.emerald,
      onPrimary: Colors.white,
      primaryContainer: AppColors.mint,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.inkSoft,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE8EEEB),
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE4F0F8),
      onTertiaryContainer: AppColors.ink,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: Color(0xFFFCE8E7),
      onErrorContainer: Color(0xFF641C1C),
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerHighest: Color(0xFFEDF2EF),
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.outline,
      outlineVariant: Color(0xFFD4DEDA),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.ink,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.emeraldBright,
    );

    return _buildTheme(scheme, AppColors.canvas);
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.emeraldBright,
      onPrimary: Color(0xFF062C27),
      primaryContainer: Color(0xFF164B43),
      onPrimaryContainer: Color(0xFFD7F6EC),
      secondary: Color(0xFFB5C8C1),
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.darkSurfaceElevated,
      onSecondaryContainer: AppColors.darkText,
      tertiary: Color(0xFF8FC5E8),
      onTertiary: Color(0xFF102A3A),
      tertiaryContainer: Color(0xFF24485D),
      onTertiaryContainer: Color(0xFFD8EEFC),
      error: Color(0xFFFF8A80),
      onError: Color(0xFF4A0909),
      errorContainer: Color(0xFF6B2525),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      surfaceContainerHighest: AppColors.darkSurfaceElevated,
      onSurfaceVariant: AppColors.darkMuted,
      outline: AppColors.darkOutline,
      outlineVariant: Color(0xFF40535C),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.darkText,
      onInverseSurface: AppColors.ink,
      inversePrimary: AppColors.emerald,
    );

    return _buildTheme(scheme, AppColors.darkCanvas);
  }

  static ThemeData _buildTheme(ColorScheme scheme, Color scaffoldBackground) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
