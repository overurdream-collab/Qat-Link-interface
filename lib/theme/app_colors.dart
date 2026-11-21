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
  static const Color pinkPrimary = Color(0xFFAD3379);
  static const Color pinkSecondary = Color(0xFFD75C9D);
  static const Color pinkBackground = Color(0xFFFFF4F9);
  static const Color pinkInk = Color(0xFF45233D);
  static const Color pinkBorder = Color(0xFFF3D6E7);

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

  // Premium branch night-mode palette (indigo/lavender); green release remains separate.
  static const Color darkPetrol = Color(0xFFAAB7FF);
  static const Color darkMint = Color(0xFF9887F5);
  static const Color darkCyan = Color(0xFF7BCFF5);
  static const Color darkInk = Color(0xFFF4F5FF);
  static const Color darkMuted = Color(0xFFBAC2DE);
  static const Color darkBackground = Color(0xFF161A38);
  static const Color darkCard = Color(0xFF242949);
  static const Color darkBorder = Color(0xFF41476B);
  static const Color darkPale = Color(0xFF30365B);
  static const Color darkSuccess = Color(0xFF4EE1A0);
  static const Color darkCanvas = darkBackground;
  static const Color darkSurface = darkCard;
  static const Color darkSurfaceElevated = Color(0xFF2A3157);
  static const Color darkOutline = darkBorder;
  static const Color darkText = darkInk;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x227C88C7),
      blurRadius: 30,
      offset: Offset(0, 13),
    ),
    BoxShadow(
      color: Color(0xDFFFFFFF),
      blurRadius: 6,
      offset: Offset(-3, -3),
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
    pale: Color(0xFFF8DCEB),
    petrol: AppColors.pinkPrimary,
    mint: AppColors.pinkSecondary,
    cyan: Color(0xFFE5A1C7),
    text: AppColors.pinkInk,
    muted: Color(0xFF866A82),
    success: AppColors.success,
    danger: AppColors.red,
    pendingText: AppColors.amber,
    pendingBackground: AppColors.pendingBackground,
  );

  static const AppThemeColors pinkDark = AppThemeColors(
    background: Color(0xFF251B30),
    card: Color(0xFF392B3D),
    cardBorder: Color(0xFF60445D),
    pale: Color(0xFF55314D),
    petrol: Color(0xFFF2A7D0),
    mint: Color(0xFFE09AC4),
    cyan: Color(0xFFCB9DE8),
    text: Color(0xFFFFEFF7),
    muted: Color(0xFFDCC1D6),
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
