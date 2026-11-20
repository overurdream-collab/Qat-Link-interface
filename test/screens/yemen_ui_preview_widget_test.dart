import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main_ui_preview.dart';
import 'package:qat_link/theme/app_colors.dart';

void main() {
  testWidgets('offline preview starts on correct Arabic login and RTL',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    expect(find.text('مقوتي لينك'), findsOneWidget);
    expect(find.text('حلقة وصل بينك وبين عملائك'), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(const Key('login_submit')))),
      TextDirection.rtl,
    );
  });

  testWidgets('preview female option changes global theme without changing debt colors',
      (tester) async {
    await tester.pumpWidget(const MaqwatiUiPreview());
    await tester.tap(find.byKey(const Key('preview_female_theme')));
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, AppColors.pinkPrimary);
    expect(app.theme!.extension<AppThemeColors>()!.danger, AppColors.red);
  });
}
