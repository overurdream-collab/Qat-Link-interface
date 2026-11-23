import 'package:flutter/material.dart';

import '../../theme/premium_tokens.dart';

/// Owner-authorized high resolution artwork. The logo already contains the
/// name and tagline; drawing a second text approximation would duplicate them.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({
    super.key,
    this.compact = false,
    this.displayHeight,
    this.artFraction = .47,
    this.referenceStyle = false,
  });

  final bool compact;
  final double? displayHeight;
  final double artFraction;
  final bool referenceStyle;

  @override
  Widget build(BuildContext context) {
    final visual = context.premium;
    final feminine = visual.feminineIdentity;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final height = displayHeight ?? (compact ? 162.0 : 236.0);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final topInset = referenceStyle
        ? 20 + 24 + MediaQuery.textScalerOf(context).scale(14) * 1.5 + 8
        : 0.0;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'مقوتي لينك، كل يوم حكاية',
      child: SizedBox(
        height: height,
        child: LayoutBuilder(builder: (context, constraints) {
          final artWidth = (constraints.maxWidth * artFraction)
              .clamp(108.0, compact ? 156.0 : 204.0)
              .toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    top: topInset,
                    end: 2,
                    bottom: referenceStyle ? 12 : 27,
                  ),
                  child: Semantics(
                    key: const Key('approved_login_tagline'),
                    label: 'كل يوم حكاية',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Keep the source logo colors, including its purple
                        // tagline, readable on dark canvases without tinting it.
                        color: Colors.white.withValues(alpha: dark ? .92 : .3),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: visual.outline),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          PremiumTokens.logoAsset,
                          key: const Key('approved_blue_3d_maqwati_wordmark'),
                          excludeFromSemantics: true,
                          cacheWidth:
                              ((constraints.maxWidth - artWidth - 14) * ratio)
                                  .ceil()
                                  .clamp(1, 1254)
                                  .toInt(),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: artWidth,
                height: height,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      left: 10,
                      bottom: compact ? 15 : 28,
                      child: Container(
                        width: artWidth * .87,
                        height: artWidth * .87,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: feminine
                                ? const [Color(0xFFF8DCEB), Color(0xFF8551B2)]
                                : const [Color(0xFFDAADFA), Color(0xFF82C9FF)],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Image.asset(
                        visual.characterAsset,
                        key: Key(feminine
                            ? 'approved_feminine_login_mascot'
                            : 'approved_masculine_login_mascot'),
                        fit: BoxFit.contain,
                        cacheHeight: (height * ratio).ceil(),
                        filterQuality: FilterQuality.high,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
