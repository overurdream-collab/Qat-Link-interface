import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main.dart';
import 'package:qat_link/theme/app_colors.dart';

void main() {
  testWidgets('Arabic onboarding uses the corrected brand and Yemeni tagline',
      (tester) async {
    await tester.pumpWidget(const QatLinkApp());

    expect(find.byKey(const Key('approved_blue_3d_maqwati_wordmark')), findsOneWidget);
    expect(find.text('كل يوم حكاية'), findsOneWidget);
    expect(find.text('مقوتي لنك'), findsNothing);
    expect(find.byKey(const Key('login_phone')), findsOneWidget);
    expect(find.byKey(const Key('login_pin')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byKey(const Key('open_registration')), findsOneWidget);
    expect(find.text('الحركة'), findsNothing);
  });

  testWidgets('onboarding layout remains RTL independently of system locale',
      (tester) async {
    await tester.pumpWidget(const QatLinkApp());

    final context = tester.element(find.text('تسجيل الدخول').first);
    expect(Directionality.of(context), TextDirection.rtl);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('ar'),
    );
  });

  testWidgets('female onboarding switches brand pink but keeps finance red',
      (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.ensureVisible(find.byKey(const Key('open_registration')));
    await tester.tap(find.byKey(const Key('open_registration')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gender_female')));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, AppColors.pinkPrimary);
    expect(
      app.theme!.extension<AppThemeColors>()!.danger,
      AppColors.red,
    );
  });

  testWidgets('login remains usable at narrow Android width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const QatLinkApp());
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
