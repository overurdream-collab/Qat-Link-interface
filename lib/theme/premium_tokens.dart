import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared screen tokens using the owner-approved green brand.
/// Decorative gradients never encode financial approval state.
abstract final class PremiumTokens {
  static const Color canvas = AppColors.background;
  static const Color ink = AppColors.ink;
  static const Color secondaryInk = AppColors.muted;
  // Compatibility names retained so existing screens keep their structure.
  static const Color blue = AppColors.petrol;
  static const Color violet = AppColors.petrol;
  static const Color lilac = AppColors.pale;
  static const Color aqua = AppColors.cyan;
  static const Color brandGreen = AppColors.mint;
  static const Color danger = Color(0xFFC42F52);
  static const Color pending = AppColors.amber;
  static const LinearGradient action = AppGradients.hero;
  static const LinearGradient wallet = AppGradients.yer;
  static const LinearGradient canvasGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [AppColors.pale, AppColors.background, AppColors.card],
  );
  static const LinearGradient darkCanvasGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [AppColors.darkCard, AppColors.darkBackground, AppColors.darkPale],
  );
  static const Color darkInk = AppColors.darkInk;
  static const Color darkSecondaryInk = AppColors.darkMuted;
  static final List<BoxShadow> floatingShadow = [
    BoxShadow(color: const Color(0xFF2E7D32).withValues(alpha: .16), blurRadius: 26, offset: const Offset(0, 13)),
    BoxShadow(color: Colors.white.withValues(alpha: .9), blurRadius: 4, offset: const Offset(-2, -3)),
  ];
}


/** Visual-only palette: carries gender-specific aesthetics, never financial
 *  approval colours. Both palettes share typography, dimensions and layout. */
@immutable
class PremiumVisualPalette extends ThemeExtension<PremiumVisualPalette> {
  const PremiumVisualPalette({
    required this.canvas,
    required this.action,
    required this.hero,
    required this.yer,
    required this.sar,
    required this.usd,
    required this.accent,
    required this.ink,
    required this.muted,
    required this.surface,
    required this.outline,
    required this.selected,
    required this.shadow,
  });

  final LinearGradient canvas, action, hero, yer, sar, usd;
  final Color accent, ink, muted, surface, outline, selected, shadow;

  static const premium = PremiumVisualPalette(
    canvas: PremiumTokens.canvasGradient,
    action: PremiumTokens.action,
    hero: AppGradients.hero,
    yer: AppGradients.yer,
    sar: AppGradients.sar,
    usd: AppGradients.usd,
    accent: AppColors.petrol, ink: AppColors.ink,
    muted: AppColors.muted,
    surface: Color(0xCCFFFFFF), outline: AppColors.cardBorder,
    selected: AppColors.pale, shadow: Color(0x272E7D32),
  );

  static const premiumDark = PremiumVisualPalette(
    canvas: PremiumTokens.darkCanvasGradient,
    action: AppGradients.hero,
    hero: LinearGradient(colors: [AppColors.darkPale, AppColors.petrol, AppColors.sea]),
    yer: AppGradients.yer,
    sar: AppGradients.sar,
    usd: AppGradients.usd,
    accent: AppColors.darkPetrol, ink: AppColors.darkInk,
    muted: AppColors.darkMuted,
    surface: AppColors.darkCard, outline: AppColors.darkBorder,
    selected: AppColors.darkPale, shadow: Color(0x55000000),
  );

  /// Female premium theme: dusty rose, raspberry, blush, orchid and lilac.
  /// Still uses strong dark ink, not pink text on a pale-pink background.
  static const feminine = PremiumVisualPalette(
    canvas: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
      colors: [Color(0xFFFFEFF6), Color(0xFFFFF9FC), Color(0xFFF3EFFF)]),
    action: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft,
      colors: [Color(0xFFAD3379), Color(0xFFAD4389), Color(0xFF8551B2)]),
    hero: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
      colors: [Color(0xFFB03F80), Color(0xFFA5458F), Color(0xFF8356B2)]),
    yer: LinearGradient(colors: [Color(0xFFA23478), Color(0xFFAC3E81), Color(0xFFB7468A)]),
    sar: LinearGradient(colors: [Color(0xFF963E77), Color(0xFFA74A82), Color(0xFFAD5388)]),
    usd: LinearGradient(colors: [Color(0xFF69429D), Color(0xFF7D4BA8), Color(0xFF8B56B6)]),
    accent: Color(0xFFAD3379), ink: Color(0xFF45233D),
    muted: Color(0xFF866A82),
    surface: Color(0xEFFFFFFF), outline: Color(0xFFF3D6E7),
    selected: Color(0xFFF8DCEB), shadow: Color(0x2B9D557D),
  );

  static const feminineDark = PremiumVisualPalette(
    canvas: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
      colors: [Color(0xFF332036), Color(0xFF251B30), Color(0xFF33253E)]),
    action: LinearGradient(colors: [Color(0xFF9F367B), Color(0xFFB84C94), Color(0xFF8060B8)]),
    hero: LinearGradient(colors: [Color(0xFF823E78), Color(0xFF913F86), Color(0xFF63468E)]),
    yer: LinearGradient(colors: [Color(0xFF8C3F79), Color(0xFFA35385), Color(0xFFAD6E98)]),
    sar: LinearGradient(colors: [Color(0xFF854A83), Color(0xFFA66A9B), Color(0xFFB47DA5)]),
    usd: LinearGradient(colors: [Color(0xFF67418E), Color(0xFF8253A2), Color(0xFF9975AF)]),
    accent: Color(0xFFF2A7D0), ink: Color(0xFFFFEFF7),
    muted: Color(0xFFDCC1D6),
    surface: Color(0xFF392B3D), outline: Color(0xFF60445D),
    selected: Color(0xFF55314D), shadow: Color(0x660C0716),
  );

  static PremiumVisualPalette select({required bool pink, required bool dark}) =>
      pink ? (dark ? feminineDark : feminine) : (dark ? premiumDark : premium);

  @override
  PremiumVisualPalette copyWith({
    LinearGradient? canvas, LinearGradient? action, LinearGradient? hero,
    LinearGradient? yer, LinearGradient? sar, LinearGradient? usd,
    Color? accent, Color? ink, Color? muted, Color? surface,
    Color? outline, Color? selected, Color? shadow,
  }) => PremiumVisualPalette(
    canvas: canvas ?? this.canvas, action: action ?? this.action,
    hero: hero ?? this.hero, yer: yer ?? this.yer,
    sar: sar ?? this.sar, usd: usd ?? this.usd,
    accent: accent ?? this.accent, ink: ink ?? this.ink,
    muted: muted ?? this.muted, surface: surface ?? this.surface,
    outline: outline ?? this.outline, selected: selected ?? this.selected,
    shadow: shadow ?? this.shadow,
  );

  @override
  PremiumVisualPalette lerp(ThemeExtension<PremiumVisualPalette>? other, double t) {
    if (other is! PremiumVisualPalette) return this;
    LinearGradient mix(LinearGradient a, LinearGradient b) =>
        (Gradient.lerp(a, b, t) as LinearGradient?) ?? a;
    return PremiumVisualPalette(
      canvas: mix(canvas, other.canvas), action: mix(action, other.action),
      hero: mix(hero, other.hero), yer: mix(yer, other.yer),
      sar: mix(sar, other.sar), usd: mix(usd, other.usd),
      accent: Color.lerp(accent, other.accent, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension PremiumVisualContext on BuildContext {
  PremiumVisualPalette get premium =>
      Theme.of(this).extension<PremiumVisualPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? PremiumVisualPalette.premiumDark : PremiumVisualPalette.premium);
}

class PremiumSurface extends StatelessWidget {
  const PremiumSurface({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 30});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final visual = context.premium;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: visual.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: visual.outline, width: 1.4),
        boxShadow: [BoxShadow(color: visual.shadow, blurRadius: 26, offset: const Offset(0, 13))],
      ),
      child: child,
    );
  }
}

class PremiumRoundButton extends StatelessWidget {
  const PremiumRoundButton({super.key, required this.icon, required this.label, this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      label: label,
      child: Material(
        color: context.premium.surface,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            height: 46, width: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.premium.outline, width: 1.6), boxShadow: [BoxShadow(color: context.premium.shadow, blurRadius: 22, offset: const Offset(0, 8))]),
            child: Icon(icon, size: 21, color: context.premium.ink),
          ),
        ),
      ),
    ),
  );
}
