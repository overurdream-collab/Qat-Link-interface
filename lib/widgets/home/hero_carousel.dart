import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Approved home carousel presentation. The actual ad service is not
/// wired yet; this displays an explicitly generic merchant welcome slide.
class HeroCarousel extends StatelessWidget {
  const HeroCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 122,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: AppColors.petrol.withValues(alpha: .13),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -48,
            left: -42,
            child: Container(
              width: 155, height: 155,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
            ),
          ),
          Positioned(
            bottom: -85,
            left: 10,
            child: Container(
              width: 142, height: 142,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10, width: 29),
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 17,
            child: Icon(
              Icons.storefront_outlined,
              color: Colors.white.withValues(alpha: .87),
              size: 49,
            ),
          ),
          const Positioned(
            top: 15,
            right: 19,
            left: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مقوتي لينك • مساحة التاجر',
                  style: TextStyle(color: Colors.white70, fontSize: 10)),
                SizedBox(height: 3),
                Text('تابع حساباتك بذكاء',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white, fontSize: 19,
                    fontWeight: FontWeight.w900,
                  )),
                SizedBox(height: 4),
                Text('ديونك وتحصيلاتك في مكان واحد',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 12,
            child: Row(
              children: [
                Container(
                  width: 16, height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(width: 4),
                for (var i = 0; i < 2; i++) ...[
                  CircleAvatar(radius: 2.5, backgroundColor: Colors.white54),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
