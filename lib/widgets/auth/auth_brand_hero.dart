import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Yemen Modern Fintech: lightweight, accessible identity used by both
/// onboarding screens. The approved Yemeni mascot stays an offline asset.
/// No embedded form controls or rasterized text: these remain real widgets.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final height = compact ? 118.0 : 168.0;

    return Semantics(
      container: true,
      label: 'مقوتي لينك، حلقة وصل بينك وبين عملائك',
      child: Container(
        width: double.infinity,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: dark
                ? [c.card, c.pale]
                : [c.card, c.pale, c.background],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.cardBorder),
        ),
        child: Stack(
          children: [
            // A restrained qamariya-inspired arc; never behind form labels.
            PositionedDirectional(
              start: -40,
              top: -78,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4A13E).withValues(alpha: .65),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 15,
              bottom: 0,
              top: 7,
              child: SizedBox(
                width: compact ? 105 : 137,
                child: Semantics(
                  image: true,
                  label: 'شخصية مقوتي اليمنية',
                  child: Image.asset(
                    'assets/images/maqwati_approved_mascot.jpeg',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person_pin_rounded,
                      color: c.petrol,
                      size: compact ? 65 : 91,
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: compact ? 116 : 146,
              end: 12,
              top: 0,
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      'مقوتي لينك',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: c.petrol,
                        fontSize: compact ? 23 : 28,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'حلقة وصل بينك وبين عملائك',
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFFB38435),
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'التاجر يسجّل، والعميل يعتمد',
                            maxLines: 2,
                            style: TextStyle(
                              color: c.muted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
