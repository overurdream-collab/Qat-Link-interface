import 'package:flutter/material.dart';

/// Isolated premium blue/violet visual experiment; green branch remains untouched.
/// Semantic money/status colors remain separate from the branding palette.
abstract final class AppColors {
  // Premium UI experiment: blue/violet/cyan. Official brand green reserved as accent.
  // The green palette is independent of the existing turquoise and female pink themes.
  static const Color officialBrandGreen = Color(0xFF6CC04A);
  static const Color petrol = Color(0xFF4C5EE6);
  static const Color mint = Color(0xFF7072F4);
  static const Color cyan = Color(0xFF86D5FA);
  static const Color sea = Color(0xFF6F46D9);
  static const Color ink = Color(0xFF151A45);
  static const Color muted = Color(0xFF777FA8);
  static const Color background = Color(0xFFF1F3FF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE3E7FA);
  static const Color pale = Color(0xFFE5E8FF);
  static const Color success = Color(0xFF16845B);
  static const Color red = Color(0xFFC04444);
  static const Color amber = Color(0xFF92400E);
  static const Color pendingBackground = Color(0xFFFEF3C7);
  // Character-detail candidates: reserved decorative accents (not user-
  // supplied exact hex values). Preserve the approved original asset itself.
  static const Color characterIvory = Color(0xFFF5EAD6);
  static const Color characterSoftGold = Color(0xFFD4AF37);
  static const Color characterDarkBrown = Color(0xFF533B2B);
  // Optional female profile identity approved in UX-03. Financial-state
  // colors remain semantic and are intentionally shared with the base theme.
  static const Color pinkPrimary = Color(0xFF96295F);
  static const Color pinkSecondary = Color(0xFFCA5C8E);
  static const Color pinkBackground = Color(0xFFFFF3F8);
  static const Color pinkInk = Color(0xFF452735);
  static const Color pinkBorder = Color(0xFFF0D4E2);

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
  static const Color darkPetrol = Color(0xFFB4F28D);
  static const Color darkMint = Color(0xFF8DDF5E);
  static const Color darkCyan = Color(0xFFC0F28F);
  static const Color darkInk = Color(0xFFF0FFE9);
  static const Color darkMuted = Color(0xFFA5BAC6);
  static const Color darkBackground = Color(0xFF15261B);
  static const Color darkCard = Color(0xFF203629);
  static const Color darkBorder = Color(0xFF45674B);
  static const Color darkPale = Color(0xFF294C30);
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
  /// Official owner-specified identity gradient; these are design tokens,
  /// not colors sampled from screenshots.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF86D5FA),
      Color(0xFF7072F4),
      Color(0xFF6F46D9),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient yer = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF6F6CE8), Color(0xFF4B88F4), Color(0xFF83D5F8)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient sar = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF45A3D9), Color(0xFF76D8F1), Color(0xFFA8E4EF)],
  );

  static const LinearGradient usd = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF7458D1), Color(0xFF997DF6), Color(0xFFB9A9F7)],
  );

  static const LinearGradient assistant = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [AppColors.petrol, AppColors.cyan],
  );
}
