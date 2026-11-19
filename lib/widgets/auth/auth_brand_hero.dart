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
      padding: EdgeInsets.fromLTRB(14, compact ? 9 : 12, 14, compact ? 11 : 14),
      decoration: BoxDecoration(
        color: dark
            ? c.card.withValues(alpha: .96)
            : Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: MaqwatiBrandColors.gold.withValues(alpha: dark ? .55 : .42),
          width: 1.2,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // This is the approved logo asset, not an unrelated illustration.
        MaqwatiBrandMark(height: compact ? 64 : 82),
        const SizedBox(height: 4),
        Text(
          'مساعدك المالي الذكي',
          key: const Key('maqwati_brand_tagline'),
          style: TextStyle(
            color: c.petrol,
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'لتجارة أنجح',
          key: const Key('maqwati_brand_promise'),
          style: TextStyle(
            color: dark ? MaqwatiBrandColors.gold : MaqwatiBrandColors.deepTeal,
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }
}
