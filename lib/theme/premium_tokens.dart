import 'package:flutter/material.dart';

/// MAQWATI premium soft-UI concept, isolated from the approved green release.
/// Decorative gradients never encode financial approval state.
abstract final class PremiumTokens {
  static const Color canvas = Color(0xFFF2F3FF);
  static const Color ink = Color(0xFF111A4B);
  static const Color secondaryInk = Color(0xFF767FAE);
  static const Color blue = Color(0xFF328BF5);
  static const Color violet = Color(0xFF7939EA);
  static const Color lilac = Color(0xFFC2A4FF);
  static const Color aqua = Color(0xFF73DCF6);
  static const Color brandGreen = Color(0xFF6CC04A);
  static const Color danger = Color(0xFFC42F52);
  static const Color pending = Color(0xFF8753C8);
  static const LinearGradient action = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [violet, Color(0xFF4358F5), aqua],
  );
  static const LinearGradient wallet = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF6E68E8), Color(0xFF488BFA), Color(0xFF8ADDFB)],
  );
  static const LinearGradient canvasGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFE9EAFF), Color(0xFFF7F7FF), Color(0xFFE5EEFF)],
  );
  static const LinearGradient darkCanvasGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF1C2149), Color(0xFF171A3C), Color(0xFF27224B)],
  );
  static const Color darkInk = Color(0xFFF3F3FF);
  static const Color darkSecondaryInk = Color(0xFFC6C9E7);
  static final List<BoxShadow> floatingShadow = [
    BoxShadow(color: const Color(0xFF737AB7).withValues(alpha: .16), blurRadius: 26, offset: const Offset(0, 13)),
    BoxShadow(color: Colors.white.withValues(alpha: .9), blurRadius: 4, offset: const Offset(-2, -3)),
  ];
}

class PremiumSurface extends StatelessWidget {
  const PremiumSurface({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 30});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF272B54) : Colors.white.withValues(alpha: .66),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: dark ? const Color(0xFF424775) : Colors.white.withValues(alpha: .90), width: 1.4),
        boxShadow: dark ? const [BoxShadow(color: Color(0x55000000), blurRadius: 20, offset: Offset(0, 9))] : PremiumTokens.floatingShadow,
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
        color: Colors.white.withValues(alpha: .72),
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            height: 46, width: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.6), boxShadow: PremiumTokens.floatingShadow),
            child: Icon(icon, size: 21, color: PremiumTokens.ink),
          ),
        ),
      ),
    ),
  );
}
