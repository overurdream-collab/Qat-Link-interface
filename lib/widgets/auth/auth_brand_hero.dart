import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Offline design assets supplied/approved by the product owner.
/// Keep the original mascot proportions and spelling: «مقوتي لينك».
abstract final class MaqwatiBrandAssets {
  static const loginBackground = 'assets/images/maqwati_login_background.jpg';
  static const horizontalLogo = 'assets/images/maqwati_horizontal_logo.jpg';
}
abstract final class MaqwatiBrandColors {
  static const deepTeal = Color(0xFF07575B);
  static const turquoise = Color(0xFF168E94);
  static const lightAqua = Color(0xFFDAF2F2);
  static const gold = Color(0xFFD4A13E);
}

/// Branded horizontal header, usable in sign-in, reports and settings.
/// If the image fails to decode, an accessible text mark is displayed.
class MaqwatiBrandMark extends StatelessWidget {
  const MaqwatiBrandMark({super.key, this.height = 78});
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'شعار مقوتي لينك',
    image: true,
    child: Image.asset(
      MaqwatiBrandAssets.horizontalLogo,
      key: const Key('maqwati_horizontal_logo'),
      height: height,
      width: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => Center(child: Text(
        'مقوتي لينك',
        style: TextStyle(color: context.colors.petrol,
          fontWeight: FontWeight.w900, fontSize: height > 75 ? 29 : 22),
      )),
    ),
  );
}

/// The approved artwork uses turquoise embroidery and a subtle gold accent.
/// This component intentionally never adds another unrelated mascot or logo.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = context.colors;
    return Container(
      key: const Key('maqwati_branded_header'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, compact ? 10 : 14, 16, compact ? 10 : 16),
      decoration: BoxDecoration(
        color: dark
          ? c.card.withValues(alpha: .95)
          : Colors.white.withValues(alpha: .90),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        MaqwatiBrandMark(height: compact ? 68 : 91),
        SizedBox(height: compact ? 5 : 8),
        Text('مساعدك المالي الذكي',
          style: TextStyle(color: c.petrol,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
