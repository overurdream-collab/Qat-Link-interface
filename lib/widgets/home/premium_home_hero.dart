import 'package:flutter/material.dart';

import '../../theme/premium_tokens.dart';

/// Compact premium campaign panel. Responsive to small Arabic screens.
/// No business action is implied by this purely informational banner.
class PremiumHomeHero extends StatelessWidget {
  const PremiumHomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'مقوتي، حسابات واضحة وتعاملات بثقة، كل عملية بموافقة الطرفين',
      child: Container(
        height: 174,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: .65), width: 1.4),
          gradient: context.premium.hero,
          boxShadow: [BoxShadow(color: context.premium.shadow,
            blurRadius: 27, offset: const Offset(0, 13))],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mascotWidth = (constraints.maxWidth * .36).clamp(86.0, 136.0).toDouble();
            return Stack(
              children: [
                PositionedDirectional(
                  start: -35, top: -63,
                  child: Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .13),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                PositionedDirectional(
                  end: -38, bottom: -100,
                  child: Container(
                    width: 230, height: 180,
                    decoration: BoxDecoration(
                      color: PremiumTokens.lilac.withValues(alpha: .42),
                      borderRadius: BorderRadius.circular(110),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 13, 7, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('مقوتي',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white, fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text('حسابات واضحة\nوتعاملات بثقة',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5, fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .22),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white54),
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text('كل عملية بموافقة الطرفين',
                                      style: TextStyle(
                                        color: Colors.white, fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: mascotWidth,
                        height: double.infinity,
                        child: Image.asset(
                          'assets/images/maqwati_approved_mascot.jpeg',
                          alignment: Alignment.bottomCenter,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
