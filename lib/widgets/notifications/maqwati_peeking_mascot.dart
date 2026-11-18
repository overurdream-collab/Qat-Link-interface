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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * .48),
            child: Container(
              decoration: BoxDecoration(
                color: MaqwatiBrandColors.deepTeal,
                border: Border.all(
                  color: MaqwatiBrandColors.gold, width: 2.4),
                borderRadius: BorderRadius.circular(size * .48),
              ),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: .34,
                  child: Image.asset(
                    MaqwatiBrandAssets.horizontalLogo,
                    height: size,
                    width: size * 3,
                    fit: BoxFit.fill,
                    key: const Key('maqwati_peek_source_logo'),
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.face_rounded,
                          size: size * .65, color: Colors.white),
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
