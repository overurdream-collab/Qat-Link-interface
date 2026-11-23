import '../helpers/brand_artwork_expectations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main_ui_preview.dart';
import 'package:qat_link/theme/app_colors.dart';

void main() {
  testWidgets('offline preview starts on correct Arabic login and RTL',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    expect(find.byKey(const Key('approved_blue_3d_maqwati_wordmark')),
        findsOneWidget);
    expectApprovedBrandArtwork(tester);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(const Key('login_submit')))),
      TextDirection.rtl,
    );
  });

  testWidgets(
      'preview female option changes global theme without changing debt colors',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.byKey(const Key('preview_female_theme')));
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, AppColors.pinkPrimary);
    expect(app.theme!.extension<AppThemeColors>()!.danger, AppColors.red);
  });

  testWidgets('customer preview stays RTL, private-account-safe and pink',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.byKey(const Key('preview_female_theme')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عميل').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer_nav_0')), findsOneWidget);
    expect(find.byKey(const Key('customer_nav_4')), findsOneWidget);
    expect(
        find.textContaining('لا تعرض بيانات أو أرصدة حقيقية'), findsOneWidget);
    expect(
        Directionality.of(
            tester.element(find.byKey(const Key('customer_nav_0')))),
        TextDirection.rtl);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, AppColors.pinkPrimary);
  });

  testWidgets('merchant preview has shared navigation but no live identity',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.text('تاجر').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('إضافة سريعة'), findsOneWidget);
    expect(find.text('معاينة تصميم فقط — لا حساب مالي متصل'), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsNothing);
  });
}
