import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The approved Yemeni mascot and qat bundle should be provided as offline
/// assets under assets/images/. Missing assets show a branded fallback.
/// The original approved artwork must never be replaced with unrelated stock.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: compact ? 190 : 293,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: dark
              ? [const Color(0xFF255D64), const Color(0xFF183743),
                  const Color(0xFF1F5362)]
              : [const Color(0xFFF9FFFE), const Color(0xFFDDF6F0),
                  const Color(0xFF9BD8D5)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: -70, bottom: -100,
            child: _glow(225, Colors.white.withValues(alpha: .21)),
          ),
          Positioned(
            right: -55, top: -80,
            child: _glow(180, AppColors.mint.withValues(alpha: .19)),
          ),
          // The original image (not a generated replacement) is used once
          // its agreed asset is committed to the repo.
          Positioned(
            left: 0, bottom: 0,
            width: compact ? 121 : 165,
            height: compact ? 153 : 220,
            child: _approvedImage(
              'assets/images/maqwati_yemeni_mascot.webp',
              icon: Icons.person_rounded,
              color: c.petrol,
            ),
          ),
          Positioned(
            right: compact ? 12 : 11,
            bottom: compact ? 10 : 21,
            width: compact ? 87 : 128,
            height: compact ? 82 : 115,
            child: _approvedImage(
              'assets/images/qat_bundles.webp',
              icon: Icons.eco_rounded,
              color: const Color(0xFF288153),
            ),
          ),
          Positioned(
            right: 12, left: 12, top: compact ? 12 : 15,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_graph_rounded,
                        color: const Color(0xFFD4A33A),
                        size: compact ? 19 : 24),
                    const SizedBox(width: 6),
                    Text(
                      'مقوتي لنك',
                      style: TextStyle(
                        color: c.petrol,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 21 : 27,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'مساعدك المالي الذكي',
                  style: TextStyle(
                    color: c.petrol,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 12 : 15,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15, vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5A2),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFD7AC4A)),
                  ),
                  child: const Text(
                    'لتجارة أنجح',
                    style: TextStyle(
                      color: Color(0xFF205457),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'حسابات واضحة، قرارات أذكى',
                    style: TextStyle(
                      color: Color(0xFF295D60),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!compact)
            Positioned(
              bottom: 10, right: 16, left: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.card.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE2BB6F),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_outlined,
                          color: c.petrol, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'التاجر يسجّل.. والعميل يعتمد',
                        style: TextStyle(
                          color: c.petrol,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _approvedImage(
    String path, {
    required IconData icon,
    required Color color,
  }) => Image.asset(
    path,
    fit: BoxFit.contain,
    alignment: Alignment.bottomCenter,
    errorBuilder: (context, error, stackTrace) => Align(
      alignment: Alignment.bottomCenter,
      child: Icon(icon, size: compact ? 59 : 85,
          color: color.withValues(alpha: .55)),
    ),
  );
}
