import 'package:flutter/material.dart';

import '../../theme/premium_tokens.dart';

/// RTL responsive brand composition for the sign-in and registration flows.
/// The stored mascot is intentionally provisional until the approved
/// blue/violet recolour is available as its own licensed image.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final height = compact ? 158.0 : 223.0;
    return Semantics(
      container: true,
      label: 'مقوتي، تعاملاتك بثقة وسهولة',
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artWidth = (constraints.maxWidth * .45)
                .clamp(105.0, compact ? 155.0 : 201.0)
                .toDouble();
            return Stack(
              children: [
                PositionedDirectional(
                  end: 10,
                  top: compact ? 20 : 25,
                  child: Container(
                    width: artWidth * .89,
                    height: artWidth * .89,
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
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8, end: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: compact ? 41 : 50,
                              height: compact ? 41 : 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: PremiumTokens.action,
                                boxShadow: PremiumTokens.floatingShadow,
                              ),
                              child: const Icon(Icons.done_all_rounded,
                                color: Colors.white, size: 27),
                            ),
                            const SizedBox(height: 9),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                'مقوتي',
                                style: TextStyle(
                                  color: dark ? Colors.white : PremiumTokens.ink,
                                  fontSize: compact ? 29 : 40,
                                  fontWeight: FontWeight.w900,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'تعاملاتك بثقة وسهولة',
                              maxLines: 2,
                              style: TextStyle(
                                color: dark ? const Color(0xFFC3C8EC) : PremiumTokens.secondaryInk,
                                fontSize: compact ? 10 : 12,
                                height: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: artWidth,
                      height: height,
                      child: Image.asset(
                        'assets/images/maqwati_approved_mascot.jpeg',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person_rounded,
                          size: 86,
                          color: PremiumTokens.violet,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
