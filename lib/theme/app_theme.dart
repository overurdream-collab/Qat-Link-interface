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
      fontFamily: 'Cairo',
      fontFamilyFallback: const ['NotoSansArabic', 'NotoSans'],
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: c.background,
      visualDensity: VisualDensity.standard,
      extensions: [c],
    );
    return base.copyWith(
      // One typographic and contrast system for every screen. Green remains
      // an accent for actions; financial status colors keep their semantics.
      textTheme: base.textTheme.apply(
        fontFamily: 'Cairo',
        bodyColor: c.text,
        displayColor: c.text,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: 'Cairo',
        bodyColor: c.text,
        displayColor: c.text,
      ),
      iconTheme: IconThemeData(color: c.text),
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
          // Lime-green call-to-action from the reference. Dark text provides
          // much stronger contrast than white on bright leaf green.
          foregroundColor: pink ? scheme.onPrimary : AppColors.ink,
          backgroundColor: pink ? scheme.primary : c.mint,
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // Shared component styling prevents per-page brand drift.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.petrol,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.petrol,
          minimumSize: const Size(48, 46),
          side: BorderSide(color: c.cardBorder, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.card,
        selectedColor: c.pale,
        side: BorderSide(color: c.cardBorder),
        labelStyle: TextStyle(color: c.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        modalBackgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
