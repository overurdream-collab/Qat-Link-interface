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
  // Optional female profile identity approved in UX-03. Financial-state
  // colors remain semantic and are intentionally shared with the base theme.
  static const Color pinkPrimary = Color(0xFFB83F78);
  static const Color pinkSecondary = Color(0xFFDE79A7);
  static const Color pinkBackground = Color(0xFFFFF4F8);
  static const Color pinkInk = Color(0xFF452735);
  static const Color pinkBorder = Color(0xFFF3D7E4);

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
class AppThemeColors extends ThemeExtension<AppThemeColors> {
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

  static const AppThemeColors pink = AppThemeColors(
    background: AppColors.pinkBackground,
    card: Colors.white,
    cardBorder: AppColors.pinkBorder,
    pale: Color(0xFFFCE4EF),
    petrol: AppColors.pinkPrimary,
    mint: AppColors.pinkSecondary,
    cyan: Color(0xFFE98DB6),
    text: AppColors.pinkInk,
    muted: Color(0xFF916A7C),
    success: AppColors.success,
    danger: AppColors.red,
    pendingText: AppColors.amber,
    pendingBackground: AppColors.pendingBackground,
  );

  static const AppThemeColors pinkDark = AppThemeColors(
    background: Color(0xFF281A22),
    card: Color(0xFF392531),
    cardBorder: Color(0xFF634354),
    pale: Color(0xFF4E3041),
    petrol: Color(0xFFF0A6C7),
    mint: Color(0xFFD875A2),
    cyan: Color(0xFFE99BC0),
    text: Color(0xFFFFEDF4),
    muted: Color(0xFFD0AFBE),
    success: AppColors.darkSuccess,
    danger: Color(0xFFFF8A80),
    pendingText: Color(0xFFEFCA86),
    pendingBackground: Color(0xFF3B3229),
  );

  @override
  AppThemeColors copyWith({
    Color? background, Color? card, Color? cardBorder, Color? pale,
    Color? petrol, Color? mint, Color? cyan, Color? text, Color? muted,
    Color? success, Color? danger, Color? pendingText,
    Color? pendingBackground,
  }) => AppThemeColors(
    background: background ?? this.background,
    card: card ?? this.card,
    cardBorder: cardBorder ?? this.cardBorder,
    pale: pale ?? this.pale,
    petrol: petrol ?? this.petrol,
    mint: mint ?? this.mint,
    cyan: cyan ?? this.cyan,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    success: success ?? this.success,
    danger: danger ?? this.danger,
    pendingText: pendingText ?? this.pendingText,
    pendingBackground: pendingBackground ?? this.pendingBackground,
  );

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      pale: Color.lerp(pale, other.pale, t)!,
      petrol: Color.lerp(petrol, other.petrol, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      pendingText: Color.lerp(pendingText, other.pendingText, t)!,
      pendingBackground: Color.lerp(pendingBackground, other.pendingBackground, t)!,
    );
  }
}

extension AppContextColors on BuildContext {
  AppThemeColors get colors => Theme.of(this).extension<AppThemeColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppThemeColors.dark
          : AppThemeColors.light);
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
