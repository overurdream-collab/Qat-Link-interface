import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/theme/app_colors.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/home/hero_carousel.dart';

void main() {
  test('seven original campaign banners use the owner-approved priority', () {
    final general = HomeCampaigns.ordered(femaleTheme: false);
    expect(general.map((b) => b.id).toList(), [
      'welcome-blue', 'close-yellow', 'eyes-blue',
      'welcome-purple', 'close-pink', 'welcome-red', 'happiness-pink',
    ]);
    expect(general.map((b) => b.assetPath).toSet().length, 7);
    final female = HomeCampaigns.ordered(femaleTheme: true);
    expect(female.first.id, 'close-pink');
    expect(female[1].id, 'happiness-pink');
    expect(female.map((b) => b.id).toSet().length, 7);
  });

  Future<void> mount(WidgetTester tester, {bool pink = false, bool dark = false}) =>
      tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(dark: dark, pink: pink),
        home: const Scaffold(body: HeroCarousel()),
      ));

  testWidgets('home displays first blue 16:9 ad and seven indicators',
      (tester) async {
    await mount(tester);
    expect(find.byKey(const Key('home_campaign_carousel')), findsOneWidget);
    expect(find.byKey(const Key('home_campaign_welcome-blue')), findsOneWidget);
    expect(find.byKey(const Key('home_campaign_indicators')), findsOneWidget);
    final view = tester.getSize(find.byType(AspectRatio).first);
    expect((view.width / view.height - 16 / 9).abs(), lessThan(.02));
  });

  testWidgets('female theme prioritizes pink banner without changing ledger red',
      (tester) async {
    await mount(tester, pink: true);
    expect(find.byKey(const Key('home_campaign_close-pink')), findsOneWidget);
    expect(AppThemeColors.pink.danger, AppColors.red);
  });

  testWidgets('pink night retains female-priority banners and dark financial semantics',
      (tester) async {
    await mount(tester, pink: true, dark: true);
    expect(find.byKey(const Key('home_campaign_close-pink')), findsOneWidget);
    expect(AppThemeColors.pinkDark.danger, AppThemeColors.dark.danger);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carousel advances after six seconds', (tester) async {
    await mount(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const Key('home_campaign_close-yellow')), findsOneWidget);
  });
}
