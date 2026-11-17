import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/home_screen.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('merchant home opens the financial assistant screen',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: HomeScreen(state: state)),
    ));

    await tester.ensureVisible(find.text('المساعد المالي الذكي'));
    await tester.tap(find.text('المساعد المالي الذكي'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchant_financial_assistant_screen')),
        findsOneWidget);
  });
}
