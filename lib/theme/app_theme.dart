import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Single theme source for all RTL pages. Shared chrome is deliberately
/// outside individual pages, so the Movement page can be replaced safely.
abstract final class AppTheme {
  static ThemeData get light => build(dark: false);
  static ThemeData get dark => build(dark: true);

  static ThemeData build({required bool dark, bool pink = false}) =>
      _build(dark, pink: pink);

  static ThemeData _build(bool isDark, {bool pink = false}) {
    final c = pink
        ? (isDark ? AppThemeColors.pinkDark : AppThemeColors.pink)
        : (isDark ? AppThemeColors.dark : AppThemeColors.light);
    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: c.petrol,
      onPrimary: isDark ? c.background : Colors.white,
      primaryContainer: c.pale,
      onPrimaryContainer: c.text,
      secondary: c.mint,
      onSecondary: c.text,
      secondaryContainer: c.pale,
      onSecondaryContainer: c.text,
      tertiary: c.cyan,
      onTertiary: c.text,
      tertiaryContainer: c.pale,
      onTertiaryContainer: c.text,
      error: c.danger,
      onError: isDark ? AppColors.ink : Colors.white,
      errorContainer: c.pendingBackground,
      onErrorContainer: c.pendingText,
      surface: c.card,
      onSurface: c.text,
      surfaceContainerHighest: c.pale,
      onSurfaceVariant: c.muted,
      outline: c.cardBorder,
      outlineVariant: c.cardBorder,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: c.text,
      onInverseSurface: c.card,
      inversePrimary: isDark ? c.mint : c.petrol,
    );
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansArabic',
      fontFamilyFallback: const ['NotoSans'],
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: c.background,
      visualDensity: VisualDensity.standard,
      extensions: [c],
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.cardBorder),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.cardBorder, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: TextStyle(color: c.card),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
