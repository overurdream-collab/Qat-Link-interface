import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main_ui_preview.dart';

void main() {
  testWidgets('customer home matches merchant banner and has 3 sliding currencies',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.text('عميل').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_campaign_carousel')), findsOneWidget);
    expect(find.byKey(const Key('customer_currency_pager')), findsOneWidget);
    expect(find.byKey(const Key('customer_currency_indicators')), findsOneWidget);
    expect(find.byKey(const Key('customer_balance_yer')), findsOneWidget);
    await tester.drag(find.byKey(const Key('customer_currency_pager')),
        const Offset(-420, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_balance_sar')), findsOneWidget);
  });

  testWidgets('studio navigation floats above a cradle and stays tappable',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.text('عميل').first);
    await tester.pumpAndSettle();
    final studio = find.byKey(const Key('customer_nav_2'));
    final other = find.byKey(const Key('customer_nav_0'));
    expect(studio, findsOneWidget);
    expect(tester.getSize(studio).width, 65);
    expect(tester.getTopLeft(studio).dy,
        lessThan(tester.getTopLeft(other).dy));
    await tester.tap(studio);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('top button order is notifications then theme then settings in RTL',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.text('عميل').first);
    await tester.pumpAndSettle();
    final notice = find.byTooltip('التنبيهات');
    final theme = find.byTooltip('الوضع الليلي');
    final settings = find.byTooltip('الضبط');
    expect(notice, findsOneWidget);
    expect(theme, findsOneWidget);
    expect(settings, findsOneWidget);
    expect(tester.getCenter(notice).dx, greaterThan(tester.getCenter(theme).dx));
    expect(tester.getCenter(theme).dx, greaterThan(tester.getCenter(settings).dx));
  });

  testWidgets('settings contain profile, packages, security and about',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.text('عميل').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('الضبط'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings_profile_name')), findsOneWidget);
    expect(find.byKey(const Key('settings_profile_address')), findsOneWidget);
    expect(find.byKey(const Key('settings_profile_phone')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings_change_password')));
    expect(find.byKey(const Key('settings_change_password')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings_packages')));
    expect(find.byKey(const Key('settings_packages')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings_privacy')));
    expect(find.byKey(const Key('settings_privacy')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings_about')));
    expect(find.byKey(const Key('settings_about')), findsOneWidget);
  });
}
