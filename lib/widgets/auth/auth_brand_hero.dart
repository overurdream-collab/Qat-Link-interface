import 'package:flutter/material.dart';

import '../../theme/premium_tokens.dart';

/// Premium hero shared by login and registration.
/// Keeps artwork optional; the approved recoloured mascot must be supplied
/// as a licensed asset before the release is declared visually complete.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 160.0 : 236.0;
    return Semantics(
      container: true,
      label: 'مقوتي، إدارة تعاملاتك بكل سهولة وأمان',
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              end: 14, top: compact ? 16 : 36,
              child: Container(
                width: compact ? 126 : 185,
                height: compact ? 126 : 185,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFFCBB4FF), Color(0xFF85C8FA)],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 3, top: compact ? 4 : 3,
              child: SizedBox(
                width: compact ? 155 : 207,
                height: compact ? 153 : 225,
                child: Image.asset(
                  'assets/images/maqwati_approved_mascot.jpeg',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.person_rounded, size: 92,
                    color: PremiumTokens.violet,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 3, top: compact ? 28 : 59,
              child: SizedBox(
                width: compact ? 145 : 188,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: compact ? 40 : 50,
                      height: compact ? 40 : 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: PremiumTokens.action,
                        boxShadow: PremiumTokens.floatingShadow,
                      ),
                      child: const Icon(Icons.done_all_rounded, color: Colors.white, size: 27),
                    ),
                    const SizedBox(height: 7),
                    Text('مقوتي',
                      maxLines: 1,
                      style: TextStyle(
                        color: PremiumTokens.ink,
                        fontSize: compact ? 27 : 38,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                    Text('تعاملاتك بثقة وسهولة',
                      maxLines: 2,
                      style: TextStyle(
                        color: PremiumTokens.secondaryInk,
                        fontSize: compact ? 10 : 12,
                        height: 1.65,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
