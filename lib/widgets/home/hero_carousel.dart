import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Ordered campaign assets from the owner's seven original banners.
/// The assets are deliberately separate from the finance/accounting layer.
/// Images remain unchanged; BoxFit.contain ensures no slogans are cut off.
@immutable
class HomeCampaignBanner {
  const HomeCampaignBanner(this.id, this.assetPath, this.label);
  final String id;
  final String assetPath;
  final String label;
}

abstract final class HomeCampaigns {
  static const List<HomeCampaignBanner> general = [
    HomeCampaignBanner('welcome-blue',
        'assets/banners/01-welcome-blue.jpeg', 'أرحبووووا — الأزرق'),
    HomeCampaignBanner('close-yellow',
        'assets/banners/02-close-yellow.jpeg', 'مقوتي قرب المسافة — الأصفر'),
    HomeCampaignBanner('eyes-blue',
        'assets/banners/03-eyes-blue.jpeg', 'مش عتقدر تغمض عينيك'),
    HomeCampaignBanner('welcome-purple',
        'assets/banners/04-welcome-purple.jpeg', 'أرحبووووا — البنفسجي'),
    HomeCampaignBanner('close-pink',
        'assets/banners/05-close-pink.jpeg', 'مقوتي قرب المسافة — الوردي'),
    HomeCampaignBanner('welcome-red',
        'assets/banners/06-welcome-red.jpeg', 'أرحبووووا — الأحمر'),
    HomeCampaignBanner('happiness-pink',
        'assets/banners/07-happiness-pink.jpeg', 'ولعتي سر سعادتي'),
  ];

  /// Female profiles still use a pink theme. Pink banners lead the rotation,
  /// but all campaigns remain available, with no duplicate asset entries.
  static List<HomeCampaignBanner> ordered({required bool femaleTheme}) {
    if (!femaleTheme) return general;
    const first = ['close-pink', 'happiness-pink'];
    return [
      for (final id in first)
        general.firstWhere((banner) => banner.id == id),
      for (final banner in general)
        if (!first.contains(banner.id)) banner,
    ];
  }
}

/// 16:9 accessible, swipable, six-second auto-rotating banner carousel.
/// Pauses while finger is pressed and while the page is not visible.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  static const _duration = Duration(seconds: 6);
  final PageController _controller = PageController();
  Timer? _timer;
  int _active = 0;
  bool _pressed = false;
  bool _female = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_duration, (_) {
      if (!mounted || _pressed || !_controller.hasClients) return;
      if (TickerMode.of(context) == false) return;
      final pages = HomeCampaigns.ordered(femaleTheme: _female);
      _controller.animateToPage(
        (_active + 1) % pages.length,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextFemale = Theme.of(context).colorScheme.primary ==
        AppColors.pinkPrimary;
    if (nextFemale != _female) {
      _female = nextFemale;
      _active = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final banners = HomeCampaigns.ordered(femaleTheme: _female);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: (_) => _pressed = true,
          onPointerUp: (_) => _pressed = false,
          onPointerCancel: (_) => _pressed = false,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: PageView.builder(
                key: const Key('home_campaign_carousel'),
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (index) => setState(() => _active = index),
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  return Semantics(
                    label: 'إعلان ${index + 1} من ${banners.length}: ${banner.label}',
                    image: true,
                    child: ColoredBox(
                      color: colors.pale,
                      child: Image.asset(
                        banner.assetPath,
                        key: Key('home_campaign_${banner.id}'),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => DecoratedBox(
                          decoration: BoxDecoration(gradient: AppGradients.hero),
                          child: Center(
                            child: Text(
                              banner.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          key: const Key('home_campaign_indicators'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: _active == i ? 19 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _active == i ? colors.petrol : colors.cardBorder,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
