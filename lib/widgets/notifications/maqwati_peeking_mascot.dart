import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_brand_hero.dart';

/// A short, accessible "peek" of the official Yemeni mascot from behind an
/// announcement card. In-app only: Android system notifications cannot render
/// this custom Flutter animation while our application is closed.
class MaqwatiPeekingMascot extends StatefulWidget {
  const MaqwatiPeekingMascot({
    super.key,
    this.animate = true,
    this.size = 88,
  });

  final bool animate;
  final double size;

  @override
  State<MaqwatiPeekingMascot> createState() => _MaqwatiPeekingMascotState();
}

class _MaqwatiPeekingMascotState extends State<MaqwatiPeekingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 960),
  );
  late final Animation<double> _rise = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS accessibility "remove animations" preference.
    if (MediaQuery.disableAnimationsOf(context) || !widget.animate) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      label: 'شخصية مقوتي لينك ترحب بك',
      image: true,
      child: SizedBox(
        key: const Key('maqwati_mascot_peek'),
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _rise,
          builder: (context, child) {
            final t = _rise.value;
            return Transform.translate(
              offset: Offset(0, (1 - t) * size * .68),
              child: Transform.rotate(
                angle: (1 - t) * .15,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            );
          },
          // The source is a 3:1 horizontal brand logo, not a portrait.
          // Its round portrait occupies approximately source x=155..555.
          // Previous OverflowBox showed x=0..512 and included the white
          // margin and broken gold arcs. Crop the artwork to the portrait
          // centre, then zoom until the character fills our whole circle.
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: MaqwatiBrandColors.deepTeal,
              border: Border.fromBorderSide(BorderSide(
                color: MaqwatiBrandColors.gold, width: 2.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.4),
              child: ClipOval(
                key: const Key('maqwati_peek_circular_crop'),
                child: SizedBox.square(
                  dimension: size,
                  child: Transform.scale(
                    scale: 1.30,
                    child: Image.asset(
                      MaqwatiBrandAssets.horizontalLogo,
                      key: const Key('maqwati_peek_source_logo'),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      // The negative X offset centres the mascot badge,
                      // rather than cropping from the start of the wordmark.
                      alignment: const Alignment(-0.81, 0),
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: MaqwatiBrandColors.deepTeal,
                        child: Icon(Icons.face_rounded,
                          size: size * .7, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable message presentation for an authenticated, *server supplied* event.
/// Never synthesize a booking, debt, amount, or approval from a visual animation.
class MaqwatiArrivalCard extends StatelessWidget {
  const MaqwatiArrivalCard({
    super.key,
    required this.title,
    required this.message,
    this.isNew = false,
    this.onTap,
    this.category = 'تنبيه',
  });
  final String title;
  final String message;
  final String category;
  final bool isNew;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: const Key('maqwati_arrival_card'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.cardBorder),
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              MaqwatiPeekingMascot(animate: isNew, size: 68),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category,
                    style: TextStyle(color: colors.petrol,
                        fontWeight: FontWeight.w700, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(title,
                    style: TextStyle(color: colors.text,
                        fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(message, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 12)),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}
