import 'package:flutter/material.dart';

/// Official colors approved from the merchant home preview on 2026-11-15.
/// Keep these tokens consistent across Home, Movement, Customers, and My Space.
abstract final class AppColors {
  // Approved light palette (exact preview values).
  static const Color petrol = Color(0xFF176B70);
  static const Color mint = Color(0xFF64C0AB);
  static const Color cyan = Color(0xFF55AFC4);
  static const Color sea = Color(0xFF438CC2);
  static const Color ink = Color(0xFF172B30);
  static const Color muted = Color(0xFF6E858B);
  static const Color background = Color(0xFFF1F8FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFDBE9EB);
  static const Color pale = Color(0xFFDDF3ED);
  static const Color success = Color(0xFF16845B);
  static const Color red = Color(0xFFC04444);
  static const Color amber = Color(0xFF92400E);
  static const Color pendingBackground = Color(0xFFFEF3C7);

  // Preview-compatible aliases; use semantic color roles for financial states.
  static const Color emerald = petrol;
  static const Color emeraldBright = mint;
  static const Color canvas = background;
  static const Color surface = card;
  static const Color outline = cardBorder;
  static const Color info = cyan;
  static const Color danger = red;
  static const Color warning = amber;
  static const Color inkSoft = muted;
  static const Color green = success;

  // Approved night mode palette (exact CSS custom properties).
  static const Color darkPetrol = Color(0xFFA2ECE2);
  static const Color darkMint = Color(0xFF69C2B2);
  static const Color darkCyan = Color(0xFF95E8F1);
  static const Color darkInk = Color(0xFFEAF5FA);
  static const Color darkMuted = Color(0xFFA5BAC6);
  static const Color darkBackground = Color(0xFF13212D);
  static const Color darkCard = Color(0xFF1D3140);
  static const Color darkBorder = Color(0xFF355060);
  static const Color darkPale = Color(0xFF284F57);
  static const Color darkSuccess = Color(0xFF4EE1A0);
  static const Color darkCanvas = darkBackground;
  static const Color darkSurface = darkCard;
  static const Color darkSurfaceElevated = Color(0xFF213747);
  static const Color darkOutline = darkBorder;
  static const Color darkText = darkInk;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x101A3A48),
      blurRadius: 17,
      offset: Offset(0, 7),
    ),
  ];
}

/// Use a semantic scheme so the same shared widgets can render in both themes.
class AppThemeColors {
  const AppThemeColors({
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.pale,
    required this.petrol,
    required this.mint,
    required this.cyan,
    required this.text,
    required this.muted,
    required this.success,
    required this.danger,
    required this.pendingText,
    required this.pendingBackground,
  });

  final Color background;
  final Color card;
  final Color cardBorder;
  final Color pale;
  final Color petrol;
  final Color mint;
  final Color cyan;
  final Color text;
  final Color muted;
  final Color success;
  final Color danger;
  final Color pendingText;
  final Color pendingBackground;

  static const AppThemeColors light = AppThemeColors(
    background: AppColors.background,
    card: AppColors.card,
    cardBorder: AppColors.cardBorder,
    pale: AppColors.pale,
    petrol: AppColors.petrol,
    mint: AppColors.mint,
    cyan: AppColors.cyan,
    text: AppColors.ink,
    muted: AppColors.muted,
    success: AppColors.success,
    danger: AppColors.red,
    pendingText: AppColors.amber,
    pendingBackground: AppColors.pendingBackground,
  );

  static const AppThemeColors dark = AppThemeColors(
    background: AppColors.darkBackground,
    card: AppColors.darkCard,
    cardBorder: AppColors.darkBorder,
    pale: AppColors.darkPale,
    petrol: AppColors.darkPetrol,
    mint: AppColors.darkMint,
    cyan: AppColors.darkCyan,
    text: AppColors.darkInk,
    muted: AppColors.darkMuted,
    success: AppColors.darkSuccess,
    danger: Color(0xFFFF8A80),
    pendingText: Color(0xFFEFCA86),
    pendingBackground: Color(0xFF3B3229),
  );
}

extension AppContextColors on BuildContext {
  AppThemeColors get colors => Theme.of(this).brightness == Brightness.dark
      ? AppThemeColors.dark
      : AppThemeColors.light;
}

/// Faithful gradients from the approved screenshot/HTML.
abstract final class AppGradients {
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [
      Color(0xFF135864),
      Color(0xFF409B9D),
      Color(0xFF8ED8CA),
    ],
    stops: [0.0, 0.52, 1.0],
  );

  static const LinearGradient yer = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [AppColors.petrol, AppColors.mint, AppColors.sea],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient sar = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [AppColors.petrol, AppColors.cyan, AppColors.mint],
  );

  static const LinearGradient usd = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF24565C), AppColors.petrol, AppColors.cyan],
  );

  static const LinearGradient assistant = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [AppColors.petrol, AppColors.cyan],
  );
}
