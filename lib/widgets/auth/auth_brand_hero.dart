import 'package:flutter/material.dart';

/// Brand composition for the owner-approved blue/lavender login preview.
/// Visual-only: the approved mascot asset stays local and unchanged.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({super.key, this.compact = false});
  final bool compact;

  static const _blue = Color(0xFF328BF5);
  static const _purple = Color(0xFF7939EA);
  static const _cyan = Color(0xFF73DCF6);

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final pink = background == const Color(0xFFFFEFF6) ||
        background == const Color(0xFF251B30);
    final accent = pink ? const Color(0xFFAD3379) : _purple;
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 365;
    final avatarWidth = compact ? 94.0 : (narrow ? 104.0 : 156.0);
    return Semantics(
      container: true,
      label: 'مقوتي لينك، كل يوم حكاية',
      child: SizedBox(
        height: compact ? 155 : 215,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              start: 12, top: 12,
              child: Container(
                width: avatarWidth + 22, height: avatarWidth + 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topRight, end: Alignment.bottomLeft,
                    colors: pink
                        ? const [Color(0xFFF8DCEB), Color(0xFF8551B2)]
                        : const [Color(0xFFC2A4FF), Color(0xFF73DCF6)],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 14, top: 14,
              child: Container(
                width: avatarWidth, height: avatarWidth,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .85), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x447939EA), blurRadius: 23, offset: Offset(0, 9)),
                  ],
                ),
                child: Image.asset(
                  'assets/images/maqwati_approved_mascot.jpeg',
                  fit: BoxFit.cover, alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.account_circle, size: 92, color: _purple),
                ),
              ),
            ),
            PositionedDirectional(
              end: 3, top: compact ? 34 : 63,
              child: SizedBox(
                width: narrow ? 150 : 205,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: pink
                              ? const [Color(0xFFF8DCEB), Color(0xFFAD4389),
                                  Color(0xFFAD3379), Color(0xFF8551B2)]
                              : const [Color(0xFF8CF6FF), Color(0xFF0FA7F9),
                                  Color(0xFF0752E6), Color(0xFF2533AE)],
                        ).createShader(bounds),
                        child: Text(
                          'مقوتي لينك',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'Cairo', fontSize: compact ? 29 : (narrow ? 26 : 35),
                            fontWeight: FontWeight.w900, color: Colors.white,
                            shadows: const [
                              Shadow(color: Color(0xFF2533AE), offset: Offset(2, 4), blurRadius: 1),
                              Shadow(color: Color(0xAA7939EA), offset: Offset(2, 7), blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'كل يوم حكاية',
                      style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w900,
                        color: pink ? accent : const Color(0xFF5730C4), fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 108, height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(colors: pink
                            ? const [Color(0xFFF8DCEB), Color(0xFFAD4389), Color(0xFF8551B2)]
                            : const [_cyan, _blue, _purple]),
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
