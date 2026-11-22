import 'package:flutter/material.dart';

import '../../theme/premium_tokens.dart';

/// Approved Maqwati Link login header, 2026-11-22.
/// Character on the left, blue raised logotype and «كل يوم حكاية» on the right.
/// No checkmark badge or extra circle above the app name.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visual = context.premium;
    final feminine = visual.feminineIdentity;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final height = compact ? 162.0 : 236.0;
    return Semantics(
      container: true,
      label: 'مقوتي لينك، كل يوم حكاية',
      child: SizedBox(
        height: height,
        child: LayoutBuilder(builder: (context, constraints) {
          final artWidth = (constraints.maxWidth * .47)
              .clamp(108.0, compact ? 156.0 : 204.0)
              .toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 0,
                    end: 2,
                    bottom: 27,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _RaisedMaqwatiWordmark(
                          compact: compact, feminine: feminine),
                      SizedBox(height: compact ? 6 : 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'كل يوم حكاية',
                          key: const Key('approved_login_tagline'),
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: feminine
                                ? (dark
                                    ? const Color(0xFFF2A7D0)
                                    : const Color(0xFFAD3379))
                                : (dark
                                    ? const Color(0xFFD7B7FF)
                                    : const Color(0xFF5730C4)),
                            fontSize: compact ? 16 : 21,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: compact ? 94 : 132,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          gradient: visual.action,
                        ),
                      ),
                    ],
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

class _RaisedMaqwatiWordmark extends StatelessWidget {
  const _RaisedMaqwatiWordmark({required this.compact, required this.feminine});

  final bool compact;
  final bool feminine;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 39.0;
    const title = 'مقوتي لينك';
    final base = TextStyle(
      fontFamily: 'Cairo',
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1.45,
      letterSpacing: -.8,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: title,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(2.5, 5),
                child: Text(
                  title,
                  textDirection: TextDirection.rtl,
                  style: base.copyWith(
                    color: feminine
                        ? const Color(0xFF632450)
                        : const Color(0xFF171C98),
                    shadows: const [
                      Shadow(
                          color: Color(0x6A2C2B9A),
                          offset: Offset(1, 7),
                          blurRadius: 7),
                    ],
                  ),
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: feminine
                      ? const [
                          Color(0xFFF8DCEB),
                          Color(0xFFAD4389),
                          Color(0xFFAD3379),
                          Color(0xFF8551B2)
                        ]
                      : (isDark
                          ? const [
                              Color(0xFF8DEBFF),
                              Color(0xFF268EFF),
                              Color(0xFF174DCB)
                            ]
                          : const [
                              Color(0xFF8CF6FF),
                              Color(0xFF0FA7F9),
                              Color(0xFF0752E6),
                              Color(0xFF2533AE)
                            ]),
                ).createShader(bounds),
                child: Text(
                  title,
                  key: const Key('approved_blue_3d_maqwati_wordmark'),
                  textDirection: TextDirection.rtl,
                  style: base.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
