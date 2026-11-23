import 'package:flutter/material.dart';

import '../../theme/premium_tokens.dart';

/// Approved Maqwati Link login header, 2026-11-22.
/// Character on the left, blue raised logotype and «كل يوم حكاية» on the right.
/// No checkmark badge or extra circle above the app name.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero(
      {super.key,
      this.compact = false,
      this.displayHeight,
      this.artFraction = .47,
      this.referenceStyle = false});

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
    return Semantics(
      container: true,
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
                    start: 0,
                    end: 2,
                    bottom: referenceStyle ? 43 : 27,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _RaisedMaqwatiWordmark(
                          compact: compact,
                          feminine: feminine,
                          referenceStyle: referenceStyle),
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
                      if (referenceStyle)
                        SizedBox(
                            width: 132,
                            height: 12,
                            child: CustomPaint(
                                painter: _BrandWavePainter(visual.action)))
                      else
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
  const _RaisedMaqwatiWordmark(
      {required this.compact,
      required this.feminine,
      this.referenceStyle = false});

  final bool compact;
  final bool feminine;
  final bool referenceStyle;

  @override
  Widget build(BuildContext context) {
    final size = referenceStyle
        ? 56.0
        : compact
            ? 30.0
            : 39.0;
    const title = 'مقوتي لينك';
    final base = TextStyle(
      fontFamily: 'Cairo',
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1.45,
      letterSpacing: -.8,
    );
    Widget wordmark(TextStyle style, {Key? key}) => referenceStyle
        ? Text.rich(
            const TextSpan(text: 'مقوتي ', children: [
              TextSpan(text: 'لينك', style: TextStyle(fontSize: 18))
            ]),
            key: key,
            textDirection: TextDirection.rtl,
            style: style)
        : Text(title, key: key, textDirection: TextDirection.rtl, style: style);
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
                child: wordmark(base.copyWith(
                  color: feminine
                      ? const Color(0xFF632450)
                      : const Color(0xFF171C98),
                  shadows: const [
                    Shadow(
                        color: Color(0x6A2C2B9A),
                        offset: Offset(1, 7),
                        blurRadius: 7),
                  ],
                )),
              ),
              if (referenceStyle)
                wordmark(base.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2.2
                      ..color = feminine
                          ? const Color(0xFFF8DCEB)
                          : PremiumTokens.aqua)),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? (feminine
                          ? const [
                              Color(0xFFF8DCEB),
                              Color(0xFFF2A7D0),
                              Color(0xFFC2A4FF)
                            ]
                          : const [
                              Color(0xFF73DCF6),
                              Color(0xFF8FB8FF),
                              Color(0xFFC2A4FF)
                            ])
                      : feminine
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
                child: wordmark(base.copyWith(color: Colors.white),
                    key: const Key('approved_blue_3d_maqwati_wordmark')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandWavePainter extends CustomPainter {
  const _BrandWavePainter(this.gradient);
  final LinearGradient gradient;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * .2)
      ..cubicTo(size.width * .25, size.height * 1.4, size.width * .7,
          -size.height * .4, size.width, size.height * .75);
    canvas.drawPath(
        path,
        Paint()
          ..shader = gradient.createShader(Offset.zero & size)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_BrandWavePainter oldDelegate) =>
      gradient != oldDelegate.gradient;
}
