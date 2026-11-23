import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit lazy content as it is built, keeping the user's text scale enabled.
Future<void> auditVerticalContent(WidgetTester tester) async {
  final targets = find
      .byWidgetPredicate((widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up))
      .hitTestable();
  if (targets.evaluate().isEmpty) return;
  for (var step = 0; step < 24; step++) {
    final position = tester.state<ScrollableState>(targets.first).position;
    if (position.pixels >= position.maxScrollExtent - .5) return;
    await tester.drag(targets.first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'Overflow while scrolling lazy content (step $step)');
  }
  final position = tester.state<ScrollableState>(targets.first).position;
  expect(position.pixels, greaterThanOrEqualTo(position.maxScrollExtent - 1),
      reason:
          'The screen end was not reachable within the audited scroll budget');
}
