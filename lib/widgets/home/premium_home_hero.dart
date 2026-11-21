import 'package:flutter/material.dart';

import '../../theme/premium_tokens.dart';

/// Purpose-built promotional surface for the approved premium visual direction.
/// A decorative promo, not a claim that AI features or purchases are enabled.
class PremiumHomeHero extends StatelessWidget {
  const PremiumHomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'مقوتي، حسابات واضحة وتعاملات بثقة',
      child: Container(
        height: 170,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: .65), width: 1.4),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFAAB8FF), Color(0xFF7478F0), Color(0xFF689CF5)],
          ),
          boxShadow: PremiumTokens.floatingShadow,
        ),
        child: Stack(children: [
          PositionedDirectional(
            start: -34, top: -45,
            child: Container(
              width: 190, height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .13),
                shape: BoxShape.circle,
              ),
            ),
          ),
          PositionedDirectional(
            end: -56, bottom: -90,
            child: Container(
              width: 240, height: 160,
              decoration: BoxDecoration(
                color: PremiumTokens.lilac.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          PositionedDirectional(
            start: 15, top: 15, bottom: 0,
            child: SizedBox(
              width: 128,
              child: Image.asset(
                'assets/images/maqwati_approved_mascot.jpeg',
                alignment: Alignment.bottomCenter,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          PositionedDirectional(
            end: 21, top: 27,
            child: SizedBox(
              width: 178,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مقوتي',
                    style: TextStyle(color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('حسابات واضحة\nوتعاملات بثقة',
                    style: TextStyle(color: Colors.white.withValues(alpha: .94),
                      fontSize: 13, fontWeight: FontWeight.w700, height: 1.6)),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .24),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white54),
                    ),
                    child: const Text('كل عملية بموافقة الطرفين',
                      style: TextStyle(color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
