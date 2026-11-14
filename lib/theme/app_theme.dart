import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 styling wired to the exact approved blue / sky / mint palette.
abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.button,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDAE7FB), // source .mini-icon
      onPrimaryContainer: AppColors.navy,
      secondary: AppColors.blueMid,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.mint,
      onSecondaryContainer: AppColors.navy,
      tertiary: AppColors.green,
      onTertiary: AppColors.navy,
      tertiaryContainer: AppColors.lime,
      onTertiaryContainer: AppColors.navy,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.redBackground,
      onErrorContainer: Color(0xFF7B2637),
      surface: AppColors.surface,
      onSurface: AppColors.navy,
      surfaceContainerHighest: AppColors.section,
      onSurfaceVariant: AppColors.inkSoft,
      outline: AppColors.background,
      outlineVariant: AppColors.background,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.navy,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.sky,
    );
    return _buildTheme(scheme, AppColors.section);
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.sky,
      onPrimary: AppColors.navy,
      primaryContainer: Color(0xFF244A85),
      onPrimaryContainer: Colors.white,
      secondary: AppColors.mint,
      onSecondary: AppColors.navy,
      secondaryContainer: AppColors.darkSurfaceElevated,
      onSecondaryContainer: AppColors.darkText,
      tertiary: AppColors.iconGreen,
      onTertiary: AppColors.navy,
      tertiaryContainer: Color(0xFF234D47),
      onTertiaryContainer: AppColors.darkText,
      error: Color(0xFFFF8A80),
      onError: Color(0xFF4A0909),
      errorContainer: Color(0xFF6B2525),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      surfaceContainerHighest: AppColors.darkSurfaceElevated,
      onSurfaceVariant: AppColors.darkMuted,
      outline: AppColors.darkOutline,
      outlineVariant: AppColors.darkOutline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.darkText,
      onInverseSurface: AppColors.navy,
      inversePrimary: AppColors.blue,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(color: scheme.onSurface, fontSize: 11),
        ),
      ),
    );
  }
}
