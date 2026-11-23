import 'dart:ui' show SemanticsAction, SemanticsFlag;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/customer_app_shell.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/app_chrome.dart';

void main() {
  for (final pink in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
          'merchant navigation announces once and accepts assistive tap '
          'pink=$pink dark=$dark', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          int? selected;
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.build(dark: dark, pink: pink),
              home: Scaffold(
                  bottomNavigationBar: AppBottomBar(
                      selectedIndex: 0,
                      onSelect: (value) => selected = value,
                      onAdd: () {}))));
          final node = tester.getSemantics(find.bySemanticsLabel('العملاء'));
          expect(node.getSemanticsData().label, 'العملاء');
          expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
          tester.binding.pipelineOwner.semanticsOwner!
              .performAction(node.id, SemanticsAction.tap);
          await tester.pump();
          expect(selected, 3);
        } finally {
          handle.dispose();
        }
      });
      testWidgets(
          'customer studio announces once and accepts assistive tap '
          'pink=$pink dark=$dark', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.build(dark: dark, pink: pink),
              home: CustomerAppShell(isDark: dark, onToggleTheme: () {})));
          await tester.pumpAndSettle();
          final node = tester.getSemantics(find.bySemanticsLabel('استديو'));
          expect(node.getSemanticsData().label, 'استديو');
          expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
          tester.binding.pipelineOwner.semanticsOwner!
              .performAction(node.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          final selected = tester.getSemantics(find.bySemanticsLabel('استديو'));
          expect(selected.getSemanticsData().hasFlag(SemanticsFlag.isSelected),
              isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          handle.dispose();
        }
      });
    }
  }
}
