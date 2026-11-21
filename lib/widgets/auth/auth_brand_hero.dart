import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Dedicated green identity, inspired by the approved Yemeni mascot mockups.
/// Uses actual Flutter text and controls, never a flattened image form.
/// The portrait is the existing local mascot; high-resolution original
/// replacement needs owner-asset verification in a separate change.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final imageSize = compact ? 70.0 : 106.0;

    return Semantics(
      container: true,
      label: 'مقوتي لينك، حلقة وصل بينك وبين عملائك',
      child: Container(
        height: compact ? 146 : 222,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: colors.cardBorder),
          color: colors.card,
          boxShadow: AppColors.cardShadow,
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              start: -60,
              top: -130,
              child: Transform.rotate(
                angle: -.22,
                child: Container(
                  width: 280,
                  height: compact ? 185 : 210,
                  decoration: BoxDecoration(
                    color: dark
                        ? colors.pale
                        : const Color(0xFFD9F6C9),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(155),
                      bottomRight: Radius.circular(115),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: -36,
              bottom: -60,
              child: Container(
                height: 130,
                width: 190,
                decoration: BoxDecoration(
                  color: colors.pale.withValues(alpha: .65),
                  borderRadius: const BorderRadius.all(Radius.elliptical(100, 65)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: compact ? 10 : 13,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'مقوتي لينك',
                            style: TextStyle(
                              color: colors.petrol,
                              fontSize: compact ? 23 : 28,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.spa_rounded,
                        size: compact ? 21 : 26,
                        color: colors.mint,
                      ),
                    ],
                  ),
                  if (!compact)
                    Text(
                      'Muqawati Link',
                      style: TextStyle(
                        color: colors.muted,
                        letterSpacing: 1.1,
                        fontSize: 11,
                      ),
                    ),
                  SizedBox(height: compact ? 5 : 8),
                  Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.pale,
                      border: Border.all(color: colors.card, width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x25245819),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/maqwati_approved_mascot.jpeg',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.account_circle_rounded,
                        color: colors.petrol,
                        size: imageSize * .75,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 9),
                  Text(
                    'حلقة وصل بينك وبين عملائك',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: compact ? 10.5 : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
